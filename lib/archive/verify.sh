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
  if [[ -f "${root}/metadata/events.jsonl" ]]; then
    local en
    en="$(wc -l <"${root}/metadata/events.jsonl" | tr -d ' ')"
    log_ok "events.jsonl present (${en} lines)"
  else
    log_warn "no metadata/events.jsonl (older archive or incomplete stage)"
  fi
  return 0
}

# Verify checksums.sha256 in place under root. Returns 0 on match, 1 on fail.
# Warns and returns 2 if file missing. Uses worker policy for large lists.
archive_verify_checksums_inplace() {
  local root="$1"
  local n workers i work rc=0
  local -a wpids=()

  if [[ ! -f "${root}/checksums.sha256" ]]; then
    log_warn "no checksums.sha256 in ${root}"
    return 2
  fi
  ui_section "Checksums"
  n="$(wc -l <"${root}/checksums.sha256" | tr -d ' ')"

  # shellcheck source=lib/core/workers.sh
  source "${LINUXBKUP_ROOT}/lib/core/workers.sh"
  workers="$(linuxbkup_workers_for "${n}" verify)"
  linuxbkup_workers_note verify "${workers}" "${n} entries"

  if [[ "${workers}" -le 1 || "${n}" -lt 16 ]]; then
    if (
      cd "${root}" && sha256sum -c checksums.sha256 --quiet
    ); then
      log_ok "all checksums matched (${n} entries)"
      return 0
    fi
    log_fatal "checksum mismatch"
    return 1
  fi

  work="$(mktemp -d "${TMPDIR:-/tmp}/linuxbkup-vfy.XXXXXX")"
  # Split manifest into N parts (round-robin)
  for ((i = 0; i < workers; i++)); do
    : >"${work}/part.${i}"
  done
  i=0
  while IFS= read -r line || [[ -n "${line}" ]]; do
    [[ -z "${line}" || "${line}" == \#* ]] && continue
    printf '%s\n' "${line}" >>"${work}/part.$((i % workers))"
    i=$((i + 1))
  done <"${root}/checksums.sha256"

  for ((i = 0; i < workers; i++)); do
    [[ -s "${work}/part.${i}" ]] || continue
    (
      cd "${root}" || exit 1
      if sha256sum -c "${work}/part.${i}" --quiet; then
        exit 0
      fi
      exit 1
    ) &
    wpids+=("$!")
  done
  for i in "${wpids[@]+"${wpids[@]}"}"; do
    if ! wait "${i}"; then
      rc=1
    fi
  done
  rm -rf "${work}"

  if [[ "${rc}" -eq 0 ]]; then
    log_ok "all checksums matched (${n} entries, ${workers} workers)"
    return 0
  fi
  log_fatal "checksum mismatch"
  return 1
}
