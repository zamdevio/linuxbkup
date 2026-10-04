# shellcheck shell=bash
# Operation-usable checks (presence ≠ usable). Keep lean — tiny fixtures only.
# Cached per process via LINUXBKUP_COMPAT_* env.

# shellcheck source=lib/core/common.sh
# (callers already have linuxbkup_require_cmd)

# Run named op checks. Args: op…  (tar_zstd|rsync|age|sha256sum)
# Returns 1 if any fail; prints clear fatals.
tools_compat_require() {
  local op rc=0
  for op in "$@"; do
    case "${op}" in
      tar_zstd)
        tools_compat_tar_zstd || rc=1
        ;;
      rsync)
        tools_compat_rsync || rc=1
        ;;
      age)
        tools_compat_age || rc=1
        ;;
      sha256sum)
        tools_compat_sha256sum || rc=1
        ;;
      *)
        log_warn "unknown compat op: ${op}"
        ;;
    esac
  done
  return "${rc}"
}

tools_compat_tar_zstd() {
  if [[ "${LINUXBKUP_COMPAT_TAR_ZSTD:-}" == "1" ]]; then
    return 0
  fi
  if ! linuxbkup_require_cmd tar zstd; then
    log_fatal "compat: tar and zstd required for archive pack/extract"
    return 1
  fi
  local tmp out
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/linuxbkup-compat-tz.XXXXXX")"
  out="${tmp}/t.zst"
  printf 'linuxbkup-compat\n' >"${tmp}/f"
  if ! tar -C "${tmp}" -cf - f 2>/dev/null | zstd -T1 -q -o "${out}" 2>/dev/null; then
    rm -rf "${tmp}"
    log_fatal "compat: tar|zstd pipe failed — check GNU tar + zstd install"
    return 1
  fi
  if ! zstd -dcq "${out}" 2>/dev/null | tar -t >/dev/null 2>&1; then
    rm -rf "${tmp}"
    log_fatal "compat: zstd|tar extract probe failed"
    return 1
  fi
  rm -rf "${tmp}"
  LINUXBKUP_COMPAT_TAR_ZSTD=1
  export LINUXBKUP_COMPAT_TAR_ZSTD
  log_verbose "compat: tar+zstd pipe OK"
  return 0
}

tools_compat_rsync() {
  if [[ "${LINUXBKUP_COMPAT_RSYNC:-}" == "1" ]]; then
    return 0
  fi
  if ! linuxbkup_require_cmd rsync; then
    log_fatal "compat: rsync required"
    return 1
  fi
  if ! rsync --version >/dev/null 2>&1; then
    log_fatal "compat: rsync present but --version failed"
    return 1
  fi
  local a b
  a="$(mktemp -d "${TMPDIR:-/tmp}/linuxbkup-compat-ra.XXXXXX")"
  b="$(mktemp -d "${TMPDIR:-/tmp}/linuxbkup-compat-rb.XXXXXX")"
  printf 'x\n' >"${a}/f"
  if ! rsync -a -- "${a}/" "${b}/" 2>/dev/null; then
    rm -rf "${a}" "${b}"
    log_fatal "compat: rsync -a probe failed (permissions?)"
    return 1
  fi
  rm -rf "${a}" "${b}"
  LINUXBKUP_COMPAT_RSYNC=1
  export LINUXBKUP_COMPAT_RSYNC
  log_verbose "compat: rsync OK"
  return 0
}

tools_compat_age() {
  if [[ "${LINUXBKUP_COMPAT_AGE:-}" == "1" ]]; then
    return 0
  fi
  if ! linuxbkup_require_cmd age age-keygen; then
    # optional tool — caller decides fatality
    return 1
  fi
  if ! age --version >/dev/null 2>&1 && ! age -version >/dev/null 2>&1; then
    # some builds print to stderr without failing
    :
  fi
  LINUXBKUP_COMPAT_AGE=1
  export LINUXBKUP_COMPAT_AGE
  log_verbose "compat: age OK"
  return 0
}

tools_compat_sha256sum() {
  if [[ "${LINUXBKUP_COMPAT_SHA256:-}" == "1" ]]; then
    return 0
  fi
  if ! linuxbkup_require_cmd sha256sum; then
    log_fatal "compat: sha256sum required"
    return 1
  fi
  local t h
  t="$(mktemp "${TMPDIR:-/tmp}/linuxbkup-compat-sha.XXXXXX")"
  printf 'x\n' >"${t}"
  h="$(sha256sum -- "${t}" 2>/dev/null | awk '{print $1}')"
  rm -f "${t}"
  if [[ ! "${h}" =~ ^[0-9a-f]{64}$ ]]; then
    log_fatal "compat: sha256sum probe produced unexpected output"
    return 1
  fi
  LINUXBKUP_COMPAT_SHA256=1
  export LINUXBKUP_COMPAT_SHA256
  log_verbose "compat: sha256sum OK"
  return 0
}
