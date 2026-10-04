# shellcheck shell=bash
# Pack staging directory into tar.zst (zstd threads from worker policy).

archive_pack_tar_zst() {
  local stage="$1"
  local dest="$2"
  local dest_dir size threads

  dest_dir="$(dirname "${dest}")"
  if [[ "${LINUXBKUP_DRY_RUN:-0}" -eq 1 ]]; then
    log_info "dry-run — would create $(term_path_link "${dest}")"
    return 0
  fi

  # shellcheck source=lib/core/workers.sh
  source "${LINUXBKUP_ROOT}/lib/core/workers.sh"
  threads="$(linuxbkup_workers_for 1 pack)"

  log_info "ensuring destination directory…"
  if ! mkdir -p "${dest_dir}"; then
    log_fatal "cannot create destination directory: ${dest_dir}"
    return 1
  fi
  if [[ ! -w "${dest_dir}" ]]; then
    log_fatal "destination directory not writable: ${dest_dir}"
    return 1
  fi

  if [[ -e "${dest}" ]]; then
    safety_require_force_overwrite "${dest}" || return 1
  fi

  linuxbkup_workers_note pack "${threads}" "tar | zstd -T${threads}"
  term_progress_status "Packing tar.zst (${threads} threads) → ${dest}"
  if ! tar -C "${stage}" -cf - . | zstd -T"${threads}" -q -o "${dest}"; then
    term_progress_end
    log_fatal "tar|zstd failed writing ${dest}"
    rm -f "${dest}" 2>/dev/null || true
    return 1
  fi
  if term_progress_enabled; then
    printf '\r'
    term_clear_eol
  fi

  if [[ ! -f "${dest}" ]]; then
    log_fatal "archive missing after pack: ${dest}"
    return 1
  fi

  log_ok "archive written"
  ui_kv_path "Archive" "${dest}"
  size="$(du -sh "${dest}" 2>/dev/null | awk '{print $1}')"
  ui_kv "Size" "${size:-?}"
}
