# shellcheck shell=bash
# Manifest load/peek + workspace helpers (split from reinstall.sh — R1).
# Nameref rule: always pass the caller's variable *name*.

# shellcheck source=modules/node.sh
[[ -n "${LINUXBKUP_ROOT:-}" ]] && source "${LINUXBKUP_ROOT}/modules/node.sh"

# Load node rows from a reinstalls.tsv file path.
# Args: tsv_path out_array_name
reinstall_load_node_rows_file() {
  local tsv="$1"
  local out_name="$2"
  local -n _load_rows="${out_name}"
  local kind path pm lock cmd
  local -a raw=()

  _load_rows=()
  [[ -f "${tsv}" ]] || return 0
  while IFS=$'\t' read -r kind path pm lock cmd || [[ -n "${kind}" ]]; do
    [[ -z "${kind}" || "${kind}" == \#* ]] && continue
    [[ "${kind}" == "node" ]] || continue
    [[ -n "${path}" && -n "${pm}" && -n "${cmd}" ]] || continue
    raw+=("${path}"$'\t'"${pm}"$'\t'"${lock}"$'\t'"${cmd}")
  done <"${tsv}"

  if ! declare -F node_filter_reinstall_rows >/dev/null 2>&1; then
    # shellcheck source=modules/node.sh
    source "${LINUXBKUP_ROOT}/modules/node.sh"
  fi
  node_filter_reinstall_rows raw "${out_name}"
  return 0
}

# Load from stage/extract root.
# Args: root out_array_name
reinstall_load_node_rows() {
  reinstall_load_node_rows_file "${1}/packages/reinstalls.tsv" "$2"
}

# Peek reinstalls.tsv from staging or archive without full extract.
# Args: backup kind(staging|archive) out_array_name
reinstall_peek_from_backup() {
  local backup="$1"
  local kind="$2"
  local out_name="$3"
  local -n _peek_rows="${out_name}"
  local tmp="" member="" prefix=""

  _peek_rows=()
  # shellcheck source=modules/node.sh
  source "${LINUXBKUP_ROOT}/modules/node.sh"

  if [[ "${kind}" == "staging" ]]; then
    reinstall_load_node_rows "${backup}" "${out_name}"
    return 0
  fi

  prefix="$(reinstall_archive_pkg_prefix "${backup}")"
  [[ -n "${prefix}" ]] || prefix="packages"
  tmp="$(mktemp "${TMPDIR:-/tmp}/linuxbkup-reinst-peek.XXXXXX")"
  for member in "${prefix}/reinstalls.tsv" "./${prefix#./}/reinstalls.tsv" "packages/reinstalls.tsv" "./packages/reinstalls.tsv"; do
    if zstd -dcq "${backup}" 2>/dev/null \
      | tar --warning=no-timestamp -xO "${member}" >"${tmp}" 2>/dev/null \
      && [[ -s "${tmp}" ]]; then
      reinstall_load_node_rows_file "${tmp}" "${out_name}"
      rm -f "${tmp}"
      return 0
    fi
    : >"${tmp}"
  done
  rm -f "${tmp}"
  return 0
}

# Detect packages/ member prefix inside a tar.zst archive (pack uses `.` from stage).
# Prints: ./packages | packages | (empty if not found)
# Args: archive_path
reinstall_archive_pkg_prefix() {
  local backup="$1"
  local list=""

  [[ -f "${backup}" ]] || return 0
  list="$(zstd -dcq "${backup}" 2>/dev/null \
    | tar --warning=no-timestamp -tf - 2>/dev/null \
    | head -n 400 || true)"
  [[ -n "${list}" ]] || return 0
  if printf '%s\n' "${list}" | grep -qE '^\./packages(/|$)'; then
    printf '%s\n' './packages'
  elif printf '%s\n' "${list}" | grep -qE '^packages(/|$)'; then
    printf '%s\n' 'packages'
  fi
}

# Extract only packages/ from an archive into dest (prefix-tolerant).
# Args: archive dest_dir
# Returns: 0 ok, 1 fail
reinstall_extract_manifest() {
  local backup="$1"
  local dest="$2"
  local prefix=""

  [[ -f "${backup}" && -d "${dest}" ]] || return 1
  prefix="$(reinstall_archive_pkg_prefix "${backup}")"
  if [[ -z "${prefix}" ]]; then
    # Last-ditch: try both member styles
    if zstd -dcq "${backup}" 2>/dev/null \
      | tar --warning=no-timestamp -C "${dest}" -xf - ./packages 2>/dev/null; then
      return 0
    fi
    zstd -dcq "${backup}" 2>/dev/null \
      | tar --warning=no-timestamp -C "${dest}" -xf - packages
    return $?
  fi
  zstd -dcq "${backup}" 2>/dev/null \
    | tar --warning=no-timestamp -C "${dest}" -xf - "${prefix}"
}

# Read package.json "name" for a dir (empty if none).
reinstall_pkg_name() {
  local dir="$1"
  local pkg="${dir}/package.json"
  [[ -f "${pkg}" ]] || return 0
  grep -oE '"name"[[:space:]]*:[[:space:]]*"[^"]+"' "${pkg}" 2>/dev/null \
    | head -n1 \
    | sed -E 's/.*"name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' || true
}

# Workspace glob patterns: pnpm-workspace.yaml packages + package.json workspaces.
# Prints one pattern per line (relative to workspace root). Path-like only.
reinstall_workspace_patterns() {
  local dir="$1"
  local yaml="" pkg="${dir}/package.json"
  local line

  yaml="${dir}/pnpm-workspace.yaml"
  [[ -f "${yaml}" ]] || yaml="${dir}/pnpm-workspace.yml"
  if [[ -f "${yaml}" ]]; then
    awk '
      /^[[:space:]]*packages[[:space:]]*:/ {p=1; next}
      p && /^[[:space:]]*-[[:space:]]*/ {
        line=$0
        sub(/^[[:space:]]*-[[:space:]]*/, "", line)
        gsub(/['\''"]/, "", line)
        gsub(/[[:space:]]*#.*$/, "", line)
        if (line != "") print line
        next
      }
      p && /^[^[:space:]#]/ {p=0}
    ' "${yaml}"
  fi
  if [[ -f "${pkg}" ]]; then
    # Only the workspaces array: "workspaces": ["packages/*", ...]
    # or object form: "workspaces": { "packages": ["packages/*"] }
    awk '
      function emit(s) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
        gsub(/['\''"]/, "", s)
        if (s ~ /\/|[*?]/ && s !~ /^workspace:/) print s
      }
      /"workspaces"[[:space:]]*:[[:space:]]*\[/ {p=1; next}
      /"workspaces"[[:space:]]*:[[:space:]]*\{/ {p=2; next}
      p==1 {
        n=split($0, a, /,/)
        for (i=1;i<=n;i++) if (match(a[i], /"[^"]+"/)) emit(substr(a[i], RSTART+1, RLENGTH-2))
        if (/\]/) p=0
        next
      }
      p==2 && /"packages"[[:space:]]*:[[:space:]]*\[/ {q=1; next}
      p==2 && q {
        n=split($0, a, /,/)
        for (i=1;i<=n;i++) if (match(a[i], /"[^"]+"/)) emit(substr(a[i], RSTART+1, RLENGTH-2))
        if (/\]/) q=0
        next
      }
      p==2 && /^[[:space:]]*}/ {p=0}
    ' "${pkg}"
  fi
}

# workspace:* dependency names declared in a package.json (root or member).
reinstall_workspace_dep_names() {
  local pkg="$1"
  [[ -f "${pkg}" ]] || return 0
  grep -oE '"[^"]+"[[:space:]]*:[[:space:]]*"workspace:' "${pkg}" 2>/dev/null \
    | sed -E 's/^"([^"]+)".*/\1/' \
    | sort -u || true
}

# Expected workspace package names + pattern misses for a workspace root.
# Prints:
#   name<TAB>ok|missing
#   PATTERN<TAB>missing-dir
reinstall_workspace_expect() {
  local dir="$1"
  local pattern d name
  local -A seen_pat=()

  while IFS= read -r pattern; do
    [[ -z "${pattern}" ]] && continue
    # Path-like globs only — never dep names / packageManager fields
    [[ "${pattern}" == */* || "${pattern}" == *[\*\?]* ]] || continue
    [[ -n "${seen_pat[${pattern}]+x}" ]] && continue
    seen_pat["${pattern}"]=1
    if [[ "${pattern}" == *[\*\?]* ]]; then
      local matches=0 dname
      while IFS= read -r d; do
        [[ -n "${d}" && -d "${d}" ]] || continue
        matches=$((matches + 1))
        if [[ -f "${d}/package.json" ]]; then
          name="$(reinstall_pkg_name "${d}")"
          [[ -n "${name}" ]] && printf '%s\tok\n' "${name}"
        fi
      done < <(compgen -G "${dir}/${pattern}" 2>/dev/null || true)
      if [[ "${matches}" -eq 0 ]]; then
        printf '%s\tmissing-dir\n' "${pattern}"
      fi
    else
      d="${dir}/${pattern}"
      if [[ ! -f "${d}/package.json" ]]; then
        printf '%s\tmissing-dir\n' "${pattern}"
      else
        name="$(reinstall_pkg_name "${d}")"
        [[ -n "${name}" ]] && printf '%s\tok\n' "${name}"
      fi
    fi
  done < <(reinstall_workspace_patterns "${dir}")

  while IFS= read -r name; do
    [[ -n "${name}" ]] && printf '%s\tdep\n' "${name}"
  done < <(reinstall_workspace_dep_names "${dir}/package.json")
}

# Names of package.json "name" fields anywhere under dir (excl. node_modules).
reinstall_workspace_found_names() {
  local dir="$1"
  local pkg name
  find "${dir}" -name package.json \
    -not -path '*/node_modules/*' \
    -not -path '*/.git/*' \
    -not -path '*/.claude/*' \
    -not -path '*/.var/*' 2>/dev/null \
    | while IFS= read -r pkg; do
      name="$(reinstall_pkg_name "$(dirname -- "${pkg}")")"
      [[ -n "${name}" ]] && printf '%s\n' "${name}"
    done | sort -u
}

# Missing workspace members for a pnpm/npm workspace root.
# Prints one missing package name per line (empty if complete).
# Also prints "PATTERN:<glob>" when a workspace glob matches no directory.
reinstall_workspace_missing() {
  local dir="$1"
  local line kind name
  local -A expected=() found=() missing_pat=()

  [[ -d "${dir}" ]] || return 0

  while IFS=$'\t' read -r name kind; do
    [[ -z "${name}" ]] && continue
    case "${kind}" in
      missing-dir) missing_pat["${name}"]=1 ;;
      *) expected["${name}"]=1 ;;
    esac
  done < <(reinstall_workspace_expect "${dir}")

  # workspace:* deps must exist even if not matched by a glob
  while IFS= read -r name; do
    [[ -n "${name}" ]] && expected["${name}"]=1
  done < <(reinstall_workspace_dep_names "${dir}/package.json")

  if [[ "${#expected[@]}" -eq 0 && "${#missing_pat[@]}" -eq 0 ]]; then
    return 0
  fi

  while IFS= read -r name; do
    [[ -n "${name}" ]] && found["${name}"]=1
  done < <(reinstall_workspace_found_names "${dir}")

  for name in "${!expected[@]}"; do
    [[ -n "${found[${name}]+x}" ]] || printf '%s\n' "${name}"
  done | sort
  for name in "${!missing_pat[@]}"; do
    printf 'PATTERN:%s\n' "${name}"
  done | sort
}

# Map a pnpm install failure log → short reason (workspace-aware).
# Args: log_file dir
reinstall_classify_fail() {
  local log_file="$1"
  local dir="${2:-}"
  local miss_line pkg_name=""

  if [[ -s "${log_file}" ]] && grep -q 'ERR_PNPM_WORKSPACE_PKG_NOT_FOUND' "${log_file}" 2>/dev/null; then
    pkg_name="$(grep -oE '"[^"]+@workspace:' "${log_file}" 2>/dev/null | head -n1 | sed -E 's/^"([^@"]+)@workspace:.*/\1/' || true)"
    [[ -z "${pkg_name}" ]] && pkg_name="$(grep -oE 'no package named "[^"]+"' "${log_file}" 2>/dev/null | head -n1 | sed -E 's/.*"([^"]+)".*/\1/' || true)"
    if [[ -n "${pkg_name}" ]]; then
      if [[ -n "${dir}" ]] && reinstall_workspace_found_names "${dir}" | grep -qx "${pkg_name}"; then
        printf '%s\n' "workspace pkg ${pkg_name} present but pnpm workspace map incomplete"
      else
        printf '%s\n' "workspace member missing from restored tree: ${pkg_name}"
      fi
      return 0
    fi
    miss_line="$(reinstall_workspace_missing "${dir}" 2>/dev/null | head -n3 | tr '\n' ',' | sed 's/,$//')"
    if [[ -n "${miss_line}" ]]; then
      printf '%s\n' "workspace members missing: ${miss_line}"
      return 0
    fi
    printf '%s\n' "ERR_PNPM_WORKSPACE_PKG_NOT_FOUND"
    return 0
  fi
  reinstall_log_error_line "${log_file}"
}
