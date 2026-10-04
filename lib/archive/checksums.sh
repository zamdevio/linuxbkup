# shellcheck shell=bash

# Write checksums.sha256 for files under stage (relative paths).
# Shows progress; never hangs silently on large trees.
archive_write_checksums() {
  local stage="$1"
  local out="${stage}/checksums.sha256"
  local list total=0 n=0

  if [[ "${LINUXBKUP_DRY_RUN:-0}" -eq 1 ]]; then
    log_info "dry-run — would write checksums.sha256"
    return 0
  fi

  list="$(mktemp "${TMPDIR:-/tmp}/linuxbkup-cksum.XXXXXX")"
  # Build file list first (no full-tree sort)
  find "${stage}" -type f ! -name 'checksums.sha256' -printf '%P\n' >"${list}" || true
  total="$(wc -l <"${list}" | tr -d ' ')"
  log_info "computing checksums for ${total} files (can take a while on large homes)…"

  : >"${out}"
  if [[ "${total}" -eq 0 ]]; then
    rm -f "${list}"
    log_ok "checksums written (0 files)"
    return 0
  fi

  (
    cd "${stage}" || exit 1
    while IFS= read -r rel || [[ -n "${rel}" ]]; do
      [[ -z "${rel}" ]] && continue
      # sha256sum prints "hash  path" — keep relative path
      sha256sum -- "${rel}" >>"${out}" || {
        log_warn "checksum failed: ${rel}"
        continue
      }
      n=$((n + 1))
      if (( n % 200 == 0 || n == total )); then
        log_info "  … hashed ${n}/${total}"
      fi
    done <"${list}"
  )
  rm -f "${list}"

  n="$(wc -l <"${out}" | tr -d ' ')"
  log_ok "checksums written (${n} files)"
}
