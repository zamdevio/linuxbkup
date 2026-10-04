# shellcheck shell=bash
# Pack staging directory into tar.zst

archive_pack_tar_zst() {
  local stage="$1"
  local dest="$2"
  local dest_dir

  dest_dir="$(dirname "${dest}")"
  if [[ "${WSLBKUP_DRY_RUN:-0}" -eq 1 ]]; then
    log_info "dry-run — would create $(term_path_link "${dest}")"
    return 0
  fi

  mkdir -p "${dest_dir}"
  if [[ -e "${dest}" ]]; then
    safety_require_force_overwrite "${dest}" || return 1
  fi

  # Create archive from stage contents
  tar -C "${stage}" -cf - . | zstd -T0 -q -o "${dest}"
  log_ok "archive written"
  ui_kv_path "Archive" "${dest}"

  local size
  size="$(du -sh "${dest}" 2>/dev/null | awk '{print $1}')"
  ui_kv "Size" "${size:-?}"
}
