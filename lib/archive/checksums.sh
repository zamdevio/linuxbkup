# shellcheck shell=bash

# Write checksums.sha256 for all files under stage (relative paths).
archive_write_checksums() {
  local stage="$1"
  local out="${stage}/checksums.sha256"

  if [[ "${WSLBKUP_DRY_RUN:-0}" -eq 1 ]]; then
    log_info "dry-run — would write checksums.sha256"
    return 0
  fi

  (
    cd "${stage}" || exit 1
    # Exclude the checksum file itself
    find . -type f ! -name 'checksums.sha256' -print0 \
      | sort -z \
      | xargs -0 sha256sum
  ) >"${out}"

  local n
  n="$(wc -l <"${out}" | tr -d ' ')"
  log_ok "checksums written (${n} files)"
}
