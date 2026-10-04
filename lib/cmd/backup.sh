# shellcheck shell=bash

wslbkup_cmd_backup() {
  if cmd_want_help "$@"; then
    wslbkup_cmd_help backup
    return 0
  fi

  # shellcheck source=lib/core/context.sh
  source "${WSLBKUP_ROOT}/lib/core/context.sh"
  # shellcheck source=lib/constraints/base.sh
  source "${WSLBKUP_ROOT}/lib/constraints/base.sh"
  # shellcheck source=lib/env/users.sh
  source "${WSLBKUP_ROOT}/lib/env/users.sh"
  # shellcheck source=lib/env/distro.sh
  source "${WSLBKUP_ROOT}/lib/env/distro.sh"
  # shellcheck source=lib/windows/paths.sh
  source "${WSLBKUP_ROOT}/lib/windows/paths.sh"
  # shellcheck source=lib/backup/stage.sh
  source "${WSLBKUP_ROOT}/lib/backup/stage.sh"
  # shellcheck source=lib/backup/home.sh
  source "${WSLBKUP_ROOT}/lib/backup/home.sh"
  # shellcheck source=modules/apt.sh
  source "${WSLBKUP_ROOT}/modules/apt.sh"
  # shellcheck source=lib/archive/checksums.sh
  source "${WSLBKUP_ROOT}/lib/archive/checksums.sh"
  # shellcheck source=lib/archive/pack.sh
  source "${WSLBKUP_ROOT}/lib/archive/pack.sh"

  cmd_context_begin backup \
    --desc "Create an intelligent backup archive." \
    --required tar zstd rsync du sha256sum \
    --optional age

  local user home stage dest dest_dir
  user="$(env_resolve_user)"
  if ! home="$(env_user_home "${user}")"; then
    log_fatal "No home directory for user: ${user}"
    return 1
  fi

  if [[ -n "${WSLBKUP_OUTPUT:-}" ]]; then
    dest="${WSLBKUP_OUTPUT}"
  else
    if ! dest_dir="$(windows_default_backup_dir)"; then
      log_fatal "Could not resolve default Downloads path — pass --output <path>"
      return 1
    fi
    dest="${dest_dir}/$(windows_default_archive_name)"
  fi
  dest_dir="$(dirname "${dest}")"

  ui_heading "Backup plan"
  ui_kv_path "Home" "${home}"
  ui_kv_path "Destination" "${dest}"
  [[ "${WSLBKUP_DRY_RUN:-0}" -eq 1 ]] && ui_kv "Mode" "dry-run"
  printf '\n'

  if [[ "${WSLBKUP_DRY_RUN:-0}" -ne 1 ]]; then
    if ! safety_confirm "Proceed with backup?" "y"; then
      log_skip "backup cancelled"
      return 1
    fi
    if ! mkdir -p "${dest_dir}"; then
      log_fatal "cannot create ${dest_dir} — is /mnt/c mounted and writable?"
      return 1
    fi
    log_ok "destination dir ready"
    ui_kv_path "Dir" "${dest_dir}"
  fi

  if [[ "${WSLBKUP_DRY_RUN:-0}" -eq 1 ]]; then
    stage="/tmp/wslbkup.dry-run.placeholder"
    log_info "dry-run — staging skipped (no files written)"
    backup_write_metadata "${stage}" "${user}" "${home}" || true
    apt_capture_manifests "${stage}" || true
    backup_copy_home "${home}" "${stage}" || true
    archive_write_checksums "${stage}" || true
    archive_pack_tar_zst "${stage}" "${dest}" || true
    printf '\n'
    log_ok "backup complete (dry-run)"
    return 0
  fi

  stage="$(backup_stage_create)"
  WSLBKUP_BACKUP_STAGE="${stage}"
  WSLBKUP_BACKUP_OK=0
  log_ok "staging: ${stage}"

  _wslbkup_backup_on_exit() {
    local rc=$?
    if [[ "${WSLBKUP_BACKUP_OK:-0}" -eq 1 ]]; then
      backup_stage_cleanup "${WSLBKUP_BACKUP_STAGE:-}"
      return 0
    fi
    if [[ -n "${WSLBKUP_BACKUP_STAGE:-}" && -d "${WSLBKUP_BACKUP_STAGE}" ]]; then
      log_warn "backup did not finish — staging kept at: ${WSLBKUP_BACKUP_STAGE}"
      log_info "Remove with: rm -rf ${WSLBKUP_BACKUP_STAGE}"
    fi
    return "${rc}"
  }
  trap '_wslbkup_backup_on_exit' EXIT
  trap 'log_fatal "interrupted during backup"; exit 130' INT TERM

  backup_write_metadata "${stage}" "${user}" "${home}"
  apt_capture_manifests "${stage}"

  if ! backup_copy_home "${home}" "${stage}"; then
    log_fatal "home/config copy aborted"
    return 1
  fi

  ui_section "Staging summary"
  ui_kv "Size" "$(du -sh "${stage}" 2>/dev/null | awk '{print $1}')"
  ui_kv_path "Stage" "${stage}"
  printf '\n'

  backup_write_index "${stage}"

  if ! archive_write_checksums "${stage}"; then
    log_fatal "checksum step failed"
    return 1
  fi

  if ! archive_pack_tar_zst "${stage}" "${dest}"; then
    log_fatal "archive pack failed"
    return 1
  fi

  WSLBKUP_BACKUP_OK=1
  backup_stage_cleanup "${stage}"
  WSLBKUP_BACKUP_STAGE=""
  trap - EXIT INT TERM

  printf '\n'
  log_ok "backup complete"
  ui_kv_path "Archive" "${dest}"
}
