# shellcheck shell=bash
# Shared verify helpers for archives and staging directories.

# Staging root: directory with checksums and/or backup metadata layout.
archive_looks_like_staging() {
  local root="$1"
  [[ -d "${root}" ]] || return 1
  [[ -f "${root}/checksums.sha256" ]] && return 0
  [[ -d "${root}/metadata" ]] && return 0
  [[ -f "${root}/INDEX" ]] && return 0
  return 1
}

# Print metadata + package summary from a staging/extract root.
archive_print_verify_summary() {
  local root="$1"
  if [[ -f "${root}/metadata/distro.env" ]]; then
    ui_section "Metadata"
    while IFS= read -r line; do
      [[ -z "${line}" || "${line}" == \#* ]] && continue
      ui_kv "${line%%=*}" "${line#*=}"
    done <"${root}/metadata/distro.env"
  fi
  if [[ -f "${root}/metadata/backup.env" ]]; then
    ui_section "Backup"
    while IFS= read -r line; do
      [[ -z "${line}" || "${line}" == \#* ]] && continue
      case "${line%%=*}" in
        version|created|user|hostname) ui_kv "${line%%=*}" "${line#*=}" ;;
      esac
    done <"${root}/metadata/backup.env"
  fi
  if [[ -f "${root}/packages/apt.manual" ]]; then
    local n
    n="$(wc -l <"${root}/packages/apt.manual" | tr -d ' ')"
    ui_kv "APT manuals" "${n}"
  fi
}

# Soft-check restore contract files. Warns if missing; returns 0 always (non-fatal for old archives).
archive_verify_schema() {
  local root="$1"
  ui_section "Schema"
  if [[ -f "${root}/metadata/schema.json" ]]; then
    local ver
    ver="$(awk -F: '/"schema_version"/{gsub(/[^0-9]/,"",$2); print $2; exit}' "${root}/metadata/schema.json" 2>/dev/null || true)"
    log_ok "schema.json present (schema_version=${ver:-?})"
  else
    log_warn "no metadata/schema.json (older archive or incomplete stage)"
  fi
  if [[ -f "${root}/metadata/decisions.tsv" ]]; then
    local n
    n="$(wc -l <"${root}/metadata/decisions.tsv" | tr -d ' ')"
    # header + rows
    log_ok "decisions.tsv present (${n} lines)"
  else
    log_warn "no metadata/decisions.tsv"
  fi
  return 0
}

# Verify checksums.sha256 in place under root. Returns 0 on match, 1 on fail.
# Warns and returns 2 if file missing.
archive_verify_checksums_inplace() {
  local root="$1"
  if [[ ! -f "${root}/checksums.sha256" ]]; then
    log_warn "no checksums.sha256 in ${root}"
    return 2
  fi
  ui_section "Checksums"
  if (
    cd "${root}" && sha256sum -c checksums.sha256 --quiet
  ); then
    local n
    n="$(wc -l <"${root}/checksums.sha256" | tr -d ' ')"
    log_ok "all checksums matched (${n} entries)"
    return 0
  fi
  log_fatal "checksum mismatch"
  return 1
}
