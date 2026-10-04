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

  # Destination
  if [[ -n "${WSLBKUP_OUTPUT:-}" ]]; then
    dest="${WSLBKUP_OUTPUT}"
  else
    if ! dest_dir="$(windows_default_backup_dir)"; then
      log_fatal "Could not resolve default Downloads path — pass --output <path>"
      return 1
    fi
    dest="${dest_dir}/$(windows_default_archive_name)"
  fi

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
  fi

  stage=""
  if [[ "${WSLBKUP_DRY_RUN:-0}" -eq 1 ]]; then
    stage="/tmp/wslbkup.dry-run.placeholder"
    log_info "dry-run — staging skipped (no files written)"
  else
    stage="$(backup_stage_create)"
    trap 'backup_stage_cleanup "'"${stage}"'"' EXIT INT TERM
    log_ok "staging: ${stage}"
  fi

  # Metadata + packages
  if [[ "${WSLBKUP_DRY_RUN:-0}" -eq 1 ]]; then
    backup_write_metadata "${stage}" "${user}" "${home}" || true
    apt_capture_manifests "${stage}" || true
    backup_copy_home "${home}" "${stage}" || true
    archive_write_checksums "${stage}" || true
    archive_pack_tar_zst "${stage}" "${dest}" || true
  else
    backup_write_metadata "${stage}" "${user}" "${home}"
    apt_capture_manifests "${stage}"
    if ! backup_copy_home "${home}" "${stage}"; then
      log_fatal "home/config copy aborted"
      return 1
    fi
    backup_write_index "${stage}"
    archive_write_checksums "${stage}"
    if ! archive_pack_tar_zst "${stage}" "${dest}"; then
      log_fatal "archive pack failed"
      return 1
    fi
    # Keep staging cleaned by trap; also clear trap after success
    backup_stage_cleanup "${stage}"
    trap - EXIT INT TERM
  fi

  printf '\n'
  log_ok "backup complete"
  if [[ "${WSLBKUP_DRY_RUN:-0}" -ne 1 ]]; then
    ui_kv_path "Archive" "${dest}"
  fi
}
