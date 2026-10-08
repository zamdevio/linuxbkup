# shellcheck shell=bash
# Compat layer — probe host tools once, map actions → portable flags.
# Doctrine: host is untrusted; never assume GNU coreutils/tar.
# Cached via LINUXBKUP_COMPAT_* env (per process).

# shellcheck source=lib/core/common.sh
# (callers already have linuxbkup_require_cmd / log_*)

# --- Stage path contract (phase 13 A) ----------------------------------------
# Shared naming for backup staging / restore extract / verify extract.
# Parent: -S/--stage-dir if set, else ${TMPDIR:-/tmp}.
# Backup basename: linuxbkup.<pid>.<rand>
# Restore/verify basename: linuxbkup-<kind>-<ts>.<pid>
compat_stage_parent() {
  if [[ -n "${LINUXBKUP_STAGE_DIR:-}" ]]; then
    printf '%s\n' "${LINUXBKUP_STAGE_DIR%/}"
  else
    printf '%s\n' "${TMPDIR:-/tmp}"
  fi
}

# Print a unique stage/extract path (not created). Args: kind
# kind: backup|restore|verify
compat_stage_path() {
  local kind="${1:-backup}" parent ts
  parent="$(compat_stage_parent)"
  ts="$(date +%Y%m%d-%H%M%S 2>/dev/null || printf 'ts')"
  if [[ "${kind}" == "backup" ]]; then
    printf '%s/linuxbkup.%s.%s\n' "${parent}" "$$" "${RANDOM}"
  else
    printf '%s/linuxbkup-%s-%s.%s\n' "${parent}" "${kind}" "${ts}" "$$"
  fi
}

# Always-print contract: ui_kv_path when available, else log_info.
# Args: label path
compat_print_stage_path() {
  local label="${1:-Stage}" path="${2:-}"
  [[ -n "${path}" ]] || return 0
  if declare -F ui_kv_path >/dev/null 2>&1; then
    ui_kv_path "${label}" "${path}"
  else
    log_info "${label}: ${path}"
  fi
}

# True if path looks like a linuxbkup stage/extract we may remove.
compat_stage_is_ours() {
  local stage="$1"
  [[ -n "${stage}" && -d "${stage}" ]] || return 1
  local parent
  parent="$(compat_stage_parent)"
  case "${stage}" in
    /tmp/linuxbkup*|"${TMPDIR:-/tmp}"/linuxbkup*) return 0 ;;
  esac
  case "${stage}" in
    "${parent}"/linuxbkup*) return 0 ;;
    "${LINUXBKUP_STAGE_DIR:-/__none__}"/linuxbkup*) return 0 ;;
  esac
  return 1
}

# --- Probes ------------------------------------------------------------------

# tar impl: gnu | busybox | bsd | unknown
compat_tar_type() {
  if [[ -n "${LINUXBKUP_COMPAT_TAR_TYPE:-}" ]]; then
    printf '%s\n' "${LINUXBKUP_COMPAT_TAR_TYPE}"
    return 0
  fi
  local t type="unknown" out=""
  t="$(command -v tar 2>/dev/null || true)"
  [[ -n "${t}" ]] || { printf '%s\n' "unknown"; return 0; }
  out="$("${t}" --version 2>&1 || true)"
  if printf '%s' "${out}" | grep -qi 'busybox'; then
    type="busybox"
  elif printf '%s' "${out}" | grep -qiE 'gnu tar|tar \(GNU'; then
    type="gnu"
  elif printf '%s' "${out}" | grep -qiE 'bsdtar|libarchive'; then
    type="bsd"
  else
    # Capability probe: GNU --warning flag
    if "${t}" --warning=no-timestamp -cf /dev/null -T /dev/null >/dev/null 2>&1; then
      type="gnu"
    else
      type="unknown"
    fi
  fi
  LINUXBKUP_COMPAT_TAR_TYPE="${type}"
  export LINUXBKUP_COMPAT_TAR_TYPE
  printf '%s\n' "${type}"
}

# sha tool: sha256sum | shasum | openssl
compat_sha_tool() {
  if [[ -n "${LINUXBKUP_COMPAT_SHA_TOOL:-}" ]]; then
    printf '%s\n' "${LINUXBKUP_COMPAT_SHA_TOOL}"
    return 0
  fi
  local tool="" t
  if t="$(command -v sha256sum 2>/dev/null)" && [[ -n "${t}" ]]; then
    if printf 'x\n' | sha256sum 2>/dev/null | grep -qE '^[0-9a-f]{64}'; then
      tool="sha256sum"
    fi
  fi
  if [[ -z "${tool}" ]] && t="$(command -v shasum 2>/dev/null)" && [[ -n "${t}" ]]; then
    if printf 'x\n' | shasum -a 256 2>/dev/null | grep -qE '^[0-9a-f]{64}'; then
      tool="shasum"
    fi
  fi
  if [[ -z "${tool}" ]] && t="$(command -v openssl 2>/dev/null)" && [[ -n "${t}" ]]; then
    if printf 'x\n' | openssl dgst -sha256 2>/dev/null | grep -qiE '[0-9a-f]{64}'; then
      tool="openssl"
    fi
  fi
  LINUXBKUP_COMPAT_SHA_TOOL="${tool}"
  export LINUXBKUP_COMPAT_SHA_TOOL
  printf '%s\n' "${tool}"
}

# rsync feature flags: prints tokens separated by spaces.
# Tokens: chown filter exclude progress
compat_rsync_feat() {
  if [[ -n "${LINUXBKUP_COMPAT_RSYNC_FEAT:-}" ]]; then
    printf '%s\n' "${LINUXBKUP_COMPAT_RSYNC_FEAT}"
    return 0
  fi
  local out="" feat=""
  [[ "$(command -v rsync 2>/dev/null)" ]] || { printf '%s\n' ""; return 0; }
  out="$(rsync --version 2>/dev/null || true)"
  [[ -n "${out}" ]] || { printf '%s\n' ""; return 0; }
  feat="filter exclude"
  if printf '%s' "${out}" | grep -q 'chown'; then
    feat="${feat} chown"
  fi
  if printf '%s' "${out}" | grep -qE 'progress2|--info='; then
    feat="${feat} progress"
  fi
  LINUXBKUP_COMPAT_RSYNC_FEAT="${feat}"
  export LINUXBKUP_COMPAT_RSYNC_FEAT
  printf '%s\n' "${feat}"
}

compat_zstd_ok() {
  [[ "${LINUXBKUP_COMPAT_ZSTD_OK:-}" == "1" ]] && return 0
  command -v zstd >/dev/null 2>&1 || return 1
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/linuxbkup-compat-zs.XXXXXX")"
  printf 'x\n' | zstd -q -o "${tmp}" 2>/dev/null || { rm -f "${tmp}"; return 1; }
  zstd -t "${tmp}" >/dev/null 2>&1 || { rm -f "${tmp}"; return 1; }
  rm -f "${tmp}"
  LINUXBKUP_COMPAT_ZSTD_OK=1
  export LINUXBKUP_COMPAT_ZSTD_OK
  return 0
}

# Probe + export all capability globals. Safe to call repeatedly.
compat_probe_all() {
  compat_tar_type >/dev/null
  compat_sha_tool >/dev/null
  compat_rsync_feat >/dev/null
  compat_find_type >/dev/null
  compat_zstd_ok || true
  if [[ -n "${LINUXBKUP_COMPAT_TAR_TYPE:-}" ]]; then
    log_verbose "compat: tar=${LINUXBKUP_COMPAT_TAR_TYPE} sha=${LINUXBKUP_COMPAT_SHA_TOOL:-none} rsync=[${LINUXBKUP_COMPAT_RSYNC_FEAT:-}] find=${LINUXBKUP_COMPAT_FIND_TYPE:-unknown} zstd=${LINUXBKUP_COMPAT_ZSTD_OK:-0}"
  fi
  return 0
}

# Print a one-line capability summary (for context banner).
compat_print_capabilities() {
  compat_probe_all
  if declare -F ui_kv >/dev/null 2>&1; then
    ui_kv "Tar" "${LINUXBKUP_COMPAT_TAR_TYPE:-unknown}"
    ui_kv "Checksum" "${LINUXBKUP_COMPAT_SHA_TOOL:-none}"
    ui_kv "Rsync" "${LINUXBKUP_COMPAT_RSYNC_FEAT:-n/a}"
    ui_kv "Find" "${LINUXBKUP_COMPAT_FIND_TYPE:-unknown}"
  fi
}

# --- find wrappers -----------------------------------------------------------

# find impl: gnu | busybox | bsd | unknown (BusyBox find has no -printf).
compat_find_type() {
  if [[ -n "${LINUXBKUP_COMPAT_FIND_TYPE:-}" ]]; then
    printf '%s\n' "${LINUXBKUP_COMPAT_FIND_TYPE}"
    return 0
  fi
  local f type="unknown" out=""
  f="$(command -v find 2>/dev/null || true)"
  [[ -n "${f}" ]] || { printf '%s\n' "unknown"; return 0; }
  out="$("${f}" --version 2>&1 || true)"
  if printf '%s' "${out}" | grep -qi 'busybox'; then
    type="busybox"
  elif printf '%s' "${out}" | grep -qiE 'gnu findutils|GNU findutils|GNU find'; then
    type="gnu"
  else
    # Capability probe: GNU -printf
    local probe
    probe="$(mktemp -d "${TMPDIR:-/tmp}/linuxbkup-find.XXXXXX")" || { printf '%s\n' "unknown"; return 0; }
    printf 'x\n' >"${probe}/f"
    if "${f}" "${probe}" -mindepth 1 -printf '%P\n' >/dev/null 2>&1; then
      type="gnu"
    else
      type="unknown"
    fi
    rm -rf "${probe}"
  fi
  LINUXBKUP_COMPAT_FIND_TYPE="${type}"
  export LINUXBKUP_COMPAT_FIND_TYPE
  printf '%s\n' "${type}"
}

# List files under root as paths relative to root (no leading ./).
# GNU: find -printf '%P\n'; BusyBox/other: (cd root && find .) + sed strip.
# Extra find args (e.g. -type f ! -name 'x') are appended before the print form.
# Args: root [find-args...]
compat_find_rel_files() {
  local root="${1:-}"
  shift || true
  [[ -n "${root}" && -d "${root}" ]] || return 0
  if [[ "$(compat_find_type 2>/dev/null || echo unknown)" == "gnu" ]]; then
    find "${root}" -mindepth 1 "$@" -printf '%P\n' 2>/dev/null || true
    return 0
  fi
  (
    cd "${root}" || exit 1
    find . -mindepth 1 "$@" 2>/dev/null | sed 's|^\./||'
  ) || true
}

# --- tar wrappers ------------------------------------------------------------

# Extra GNU-only flags when supported.
_compat_tar_warn_args() {
  case "${LINUXBKUP_COMPAT_TAR_TYPE:-}" in
    gnu) printf '%s\n' "--warning=no-timestamp" ;;
    *) printf '%s\n' "" ;;
  esac
}

# Pack stage dir → stdout tar stream. Args: stage [exclude_glob...]
compat_tar_pack_stream() {
  local stage="$1"
  shift || true
  local -a cmd=(tar -C "${stage}")
  local w g
  w="$(_compat_tar_warn_args)"
  [[ -n "${w}" ]] && cmd+=("${w}")
  for g in "$@"; do
    [[ -z "${g}" ]] && continue
    cmd+=(--exclude "${g}")
  done
  cmd+=(-cf - .)
  "${cmd[@]}"
}

# Extract tar stream (stdin) → dest. Args: dest [member...]
# BusyBox/BSD: no --warning; -C -xf - is portable.
compat_tar_extract_stream() {
  local dest="$1"
  shift || true
  mkdir -p "${dest}" || return 1
  local -a cmd=(tar -C "${dest}")
  local w
  w="$(_compat_tar_warn_args)"
  [[ -n "${w}" ]] && cmd+=("${w}")
  cmd+=(-xf -)
  [[ $# -gt 0 ]] && cmd+=("$@")
  "${cmd[@]}"
}

# List members from a tar stream (stdin). Prints member names.
compat_tar_list_stream() {
  local -a cmd=(tar)
  local w
  w="$(_compat_tar_warn_args)"
  [[ -n "${w}" ]] && cmd+=("${w}")
  cmd+=(-tf -)
  "${cmd[@]}"
}

# Extract one member from a tar stream to stdout. Args: member
compat_tar_member_stream() {
  local member="$1"
  local -a cmd=(tar)
  local w
  w="$(_compat_tar_warn_args)"
  [[ -n "${w}" ]] && cmd+=("${w}")
  cmd+=(-xO -f - "${member}")
  if "${cmd[@]}"; then
    return 0
  fi
  # Fallback: extract to temp then cat (slow but portable)
  local tmp
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/linuxbkup-compat-mem.XXXXXX")"
  local -a xcmd=(tar -C "${tmp}")
  [[ -n "${w}" ]] && xcmd+=("${w}")
  xcmd+=(-xf - "${member}")
  if "${xcmd[@]}" 2>/dev/null && [[ -f "${tmp}/${member#./}" ]]; then
    cat "${tmp}/${member#./}"
    rm -rf "${tmp}"
    return 0
  fi
  rm -rf "${tmp}"
  return 1
}

# zstd decompress file → stdout (portable flags).
compat_zstd_decompress() {
  local src="$1"
  zstd -dcq "${src}" 2>/dev/null
}

# zstd compress stdin → dest file. Args: dest [threads]
compat_zstd_compress() {
  local dest="$1"
  local threads="${2:-1}"
  if [[ "${threads}" =~ ^[0-9]+$ ]] && [[ "${threads}" -gt 1 ]]; then
    zstd -T"${threads}" -q -o "${dest}" 2>/dev/null
  else
    zstd -q -o "${dest}" 2>/dev/null
  fi
}

# --- sha256 wrappers ---------------------------------------------------------

# Hash files/streams. Args: file...  OR stdin if no file and stdin not tty.
# Prints sha256sum-format lines: <hash>  <name>
compat_sha256_hash() {
  local tool
  tool="$(compat_sha_tool)"
  [[ -n "${tool}" ]] || return 1
  local -a files=()
  files=("$@")
  if [[ ${#files[@]} -eq 0 ]]; then
    # stdin
    case "${tool}" in
      sha256sum) sha256sum 2>/dev/null ;;
      shasum) shasum -a 256 2>/dev/null ;;
      openssl)
        local h
        h="$(openssl dgst -sha256 2>/dev/null | awk '{print $NF}')"
        [[ -n "${h}" ]] && printf '%s  -\n' "${h}"
        ;;
    esac
    return 0
  fi
  case "${tool}" in
    sha256sum) sha256sum -- "${files[@]}" 2>/dev/null ;;
    shasum) shasum -a 256 -- "${files[@]}" 2>/dev/null ;;
    openssl)
      local f h
      for f in "${files[@]}"; do
        h="$(openssl dgst -sha256 -- "${f}" 2>/dev/null | awk '{print $NF}')"
        [[ -n "${h}" ]] && printf '%s  %s\n' "${h}" "${f}"
      done
      ;;
  esac
}

# Verify checksum file (sha256sum -c style) under cwd. Args: ckfile
# Returns 0 ok, 1 mismatch, 2 tool missing.
compat_sha256_check_file() {
  local ckfile="$1"
  local tool
  tool="$(compat_sha_tool)"
  [[ -n "${tool}" && -f "${ckfile}" ]] || return 2
  case "${tool}" in
    sha256sum)
      sha256sum -c "${ckfile}" --quiet >/dev/null 2>&1
      return $?
      ;;
    shasum)
      shasum -a 256 -c "${ckfile}" --quiet >/dev/null 2>&1
      return $?
      ;;
    openssl)
      # Manual walk: <hash>  <path>
      local hash path actual line
      local rc=0
      while IFS= read -r line || [[ -n "${line}" ]]; do
        [[ -z "${line}" || "${line}" == \#* ]] && continue
        hash="${line%% *}"
        path="${line#*  }"
        [[ "${path}" == "${line}" ]] && path="${line#* }"
        [[ -f "${path}" ]] || { rc=1; continue; }
        actual="$(openssl dgst -sha256 -- "${path}" 2>/dev/null | awk '{print $NF}')"
        [[ "${actual}" == "${hash}" ]] || rc=1
      done <"${ckfile}"
      return "${rc}"
      ;;
  esac
  return 2
}

# --- numfmt / human sizes ----------------------------------------------------

# Bytes → human string. Uses numfmt when present; pure-bash IEC fallback.
compat_numfmt_human() {
  local bytes="${1:-0}"
  [[ "${bytes}" =~ ^[0-9]+$ ]] || bytes=0
  if command -v numfmt >/dev/null 2>&1; then
    if numfmt --to=iec --suffix=B "${bytes}" 2>/dev/null; then
      return 0
    fi
  fi
  if [[ "${bytes}" -lt 1024 ]]; then
    printf '%sB\n' "${bytes}"
    return 0
  fi
  local units=(B K M G T P) i=0 v="${bytes}"
  while [[ "${v}" -ge 1024 && $((i + 1)) -lt ${#units[@]} ]]; do
    v=$((v / 1024))
    i=$((i + 1))
  done
  printf '%s%s\n' "${v}" "${units[$i]}"
}

# --- rsync metadata mode -----------------------------------------------------

# Detect whether dest filesystem is likely non-Linux (FAT/exFAT/NTFS/9p/…).
# Args: dest_path  → prints 1 (metadata mode) or 0
compat_rsync_needs_meta() {
  local dest="${1:-}"
  [[ -n "${dest}" ]] || { printf '0\n'; return 0; }
  local parent="${dest}" fstype=""
  # Climb to an existing ancestor for findmnt/stat
  while [[ ! -d "${parent}" && "${parent}" != "/" && "${parent}" != "." ]]; do
    parent="$(dirname -- "${parent}")"
  done
  if command -v findmnt >/dev/null 2>&1; then
    fstype="$(findmnt -no FSTYPE --target "${parent}" 2>/dev/null || true)"
  fi
  if [[ -z "${fstype}" ]] && command -v stat >/dev/null 2>&1; then
    # stat -f %T is filesystem type (linux: tmpfs etc; busybox may lack it)
    fstype="$(stat -f -c %T "${parent}" 2>/dev/null || true)"
  fi
  case "${fstype}" in
    vfat|exfat|fat|msdos|ntfs|ntfs3|fuseblk|9p|drvfs|fuse.rclone|fuseblk)
      printf '1\n'
      return 0
      ;;
  esac
  # Probe: can we chmod + symlink on dest?
  if [[ -d "${parent}" && -w "${parent}" ]]; then
    local probe="${parent}/.linuxbkup-compat-probe.$$"
    mkdir -p "${probe}" 2>/dev/null || { printf '1\n'; return 0; }
    if ! chmod 700 "${probe}" 2>/dev/null; then
      rm -rf "${probe}" 2>/dev/null || true
      printf '1\n'
      return 0
    fi
    if ! ln -sfn "${probe}" "${probe}.link" 2>/dev/null; then
      rm -rf "${probe}" "${probe}.link" 2>/dev/null || true
      printf '1\n'
      return 0
    fi
    rm -rf "${probe}" "${probe}.link" 2>/dev/null || true
  fi
  printf '0\n'
  return 0
}

# Build rsync base args for a dest (metadata mode when needed).
# Prints args one per line (safe to mapfile).
# Args: dest [--chown=user:group]
compat_rsync_args_for() {
  local dest="$1"
  shift || true
  local meta
  meta="$(compat_rsync_needs_meta "${dest}")"
  local -a args=()
  if [[ "${meta}" == "1" ]]; then
    # No -a: avoid chmod/symlink failures on FAT/exFAT/NTFS/9p.
    # Recursive + links as symlinks best-effort + preserve times when allowed.
    args=(-rlt --no-perms --no-group --no-owner)
    args+=(--exclude '.linuxbkup-compat-probe.*')
  else
    args=(-a)
  fi
  local a
  for a in "$@"; do
    [[ -z "${a}" ]] && continue
    # --chown needs rsync 3.1+ and a capable FS — skip in metadata mode
    if [[ "${meta}" == "1" && "${a}" == --chown=* ]]; then
      continue
    fi
    args+=("${a}")
  done
  printf '%s\n' "${args[@]}"
  [[ "${meta}" == "1" ]] && LINUXBKUP_COMPAT_RSYNC_META=1
  export LINUXBKUP_COMPAT_RSYNC_META 2>/dev/null || true
}

# Run rsync with portable args. Extra args appended. Returns rsync rc.
# Usage: compat_rsync_copy src dest [extra rsync args...]
compat_rsync_copy() {
  local src="$1" dest="$2"
  shift 2 || true
  local -a built=()
  mapfile -t built < <(compat_rsync_args_for "${dest}" "$@")
  [[ "${#built[@]}" -gt 0 ]] || built=(-a)
  rsync "${built[@]}" -- "${src}/" "${dest}/"
}

# --- Schema / tool version gates (D4) ----------------------------------------

LINUXBKUP_SCHEMA_SUPPORTED="${LINUXBKUP_SCHEMA_SUPPORTED:-1}"

# Soft-gate schema.json + tool_version. Args: extract_root
# Returns 0 (soft-warn ok), 1 hard incompat.
compat_schema_gate() {
  local root="$1"
  local sch="${root}/metadata/schema.json"
  [[ -f "${sch}" ]] || return 0
  local schema="" ver="" tool=""
  schema="$(awk -F'"' '/"schema"[[:space:]]*:/ {print $4; exit}' "${sch}" 2>/dev/null || true)"
  ver="$(awk -F: '/"schema_version"/{gsub(/[^0-9]/,"",$2); print $2; exit}' "${sch}" 2>/dev/null || true)"
  tool="$(awk -F'"' '/"tool_version"/ {print $4; exit}' "${sch}" 2>/dev/null || true)"
  [[ -n "${schema}" ]] || return 0
  case "${schema}" in
    linuxbkup.schema/*) ;;
    *)
      log_warn "unknown schema id '${schema}' — best-effort restore"
      return 0
      ;;
  esac
  if [[ -n "${ver}" && "${ver}" =~ ^[0-9]+$ ]]; then
    if [[ "${ver}" -gt "${LINUXBKUP_SCHEMA_SUPPORTED}" ]]; then
      log_warn "archive schema_version=${ver} newer than supported=${LINUXBKUP_SCHEMA_SUPPORTED} — best-effort restore"
    fi
  fi
  if [[ -n "${tool}" ]]; then
    log_verbose "archive tool_version=${tool}"
  fi
  return 0
}
