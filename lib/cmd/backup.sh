# shellcheck shell=bash

linuxbkup_cmd_backup() {
  if cmd_want_help "$@"; then
    linuxbkup_cmd_help backup
    return 0
  fi

  # shellcheck source=lib/core/context.sh
  source "${LINUXBKUP_ROOT}/lib/core/context.sh"
  # shellcheck source=lib/constraints/base.sh
  source "${LINUXBKUP_ROOT}/lib/constraints/base.sh"
  # shellcheck source=lib/env/users.sh
  source "${LINUXBKUP_ROOT}/lib/env/users.sh"
  # shellcheck source=lib/env/distro.sh
  source "${LINUXBKUP_ROOT}/lib/env/distro.sh"
  # shellcheck source=lib/core/platform/paths.sh
  source "${LINUXBKUP_ROOT}/lib/core/platform/paths.sh"
  # shellcheck source=lib/backup/stage.sh
  source "${LINUXBKUP_ROOT}/lib/backup/stage.sh"
  # shellcheck source=lib/backup/home.sh
  source "${LINUXBKUP_ROOT}/lib/backup/home.sh"
  # shellcheck source=modules/apt.sh
  source "${LINUXBKUP_ROOT}/modules/apt.sh"
  # shellcheck source=lib/archive/checksums.sh
  source "${LINUXBKUP_ROOT}/lib/archive/checksums.sh"
  # shellcheck source=lib/archive/pack.sh
  source "${LINUXBKUP_ROOT}/lib/archive/pack.sh"
  # shellcheck source=lib/classify/plan.sh
  source "${LINUXBKUP_ROOT}/lib/classify/plan.sh"

  LINUXBKUP_PERM_SKIPS=0

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
  LINUXBKUP_HOME="${home}"
  export LINUXBKUP_HOME

  if [[ -n "${LINUXBKUP_OUTPUT:-}" ]]; then
    dest="${LINUXBKUP_OUTPUT}"
  else
    dest="$(platform_default_archive_path)"
  fi
  dest_dir="$(dirname "${dest}")"

  log_verbose "backup target user=${user} home=${home}"
  log_debug "dest=${dest} dry_run=${LINUXBKUP_DRY_RUN:-0} yes=${LINUXBKUP_YES:-0}"

  ui_heading "Backup"
  ui_kv_path "Home" "${home}"
  ui_kv_path "Destination" "${dest}"
  [[ "${LINUXBKUP_DRY_RUN:-0}" -eq 1 ]] && ui_kv "Mode" "dry-run"
  printf '\n'

  if [[ "${LINUXBKUP_DRY_RUN:-0}" -ne 1 ]]; then
    if ! safety_confirm "Proceed with backup?" "y"; then
      log_skip "backup cancelled"
      return 1
    fi
    if ! mkdir -p "${dest_dir}"; then
      log_fatal "cannot create ${dest_dir} — check permissions or pass --output <path>"
      return 1
    fi
    log_ok "destination dir ready"
    ui_kv_path "Dir" "${dest_dir}"
  fi

  if [[ "${LINUXBKUP_DRY_RUN:-0}" -eq 1 ]]; then
    stage="/tmp/linuxbkup.dry-run.placeholder"
    log_info "dry-run — staging skipped (no files written)"
    backup_write_metadata "${stage}" "${user}" "${home}" || true
    apt_capture_manifests "${stage}" || true
    backup_copy_home "${home}" "${stage}" || true
    printf '\n'
    classify_print_backup_summary "${home}"
    printf '\n'
    log_ok "backup complete (dry-run)"
    return 0
  fi

  stage="$(backup_stage_create)"
  LINUXBKUP_BACKUP_STAGE="${stage}"
  LINUXBKUP_BACKUP_OK=0
  log_ok "staging: ${stage}"
  log_debug "staging created at ${stage}"

  _linuxbkup_backup_on_exit() {
    local rc=$?
    if [[ "${LINUXBKUP_BACKUP_OK:-0}" -eq 1 ]]; then
      backup_stage_cleanup "${LINUXBKUP_BACKUP_STAGE:-}"
      return 0
    fi
    if [[ -n "${LINUXBKUP_BACKUP_STAGE:-}" && -d "${LINUXBKUP_BACKUP_STAGE}" ]]; then
      log_warn "backup did not finish — staging kept at: ${LINUXBKUP_BACKUP_STAGE}"
      log_info "Remove with: rm -rf ${LINUXBKUP_BACKUP_STAGE}"
      log_info "Or verify: linuxbkup verify ${LINUXBKUP_BACKUP_STAGE}"
    fi
    return "${rc}"
  }
  trap '_linuxbkup_backup_on_exit' EXIT
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

  if ! backup_write_index "${stage}"; then
    log_fatal "INDEX step failed"
    return 1
  fi

  if ! archive_write_checksums "${stage}"; then
    log_fatal "checksum step failed"
    return 1
  fi

  if ! archive_pack_tar_zst "${stage}" "${dest}"; then
    log_fatal "archive pack failed"
    return 1
  fi

  LINUXBKUP_BACKUP_OK=1
  if [[ "${LINUXBKUP_KEEP_STAGE:-0}" -eq 1 ]]; then
    log_info "keeping staging (--keep-stage): ${stage}"
    LINUXBKUP_BACKUP_STAGE=""
  else
    backup_stage_cleanup "${stage}"
    LINUXBKUP_BACKUP_STAGE=""
  fi
  trap - EXIT INT TERM

  printf '\n'
  classify_print_backup_summary "${home}"
  printf '\n'
  log_ok "backup complete"
  ui_kv_path "Archive" "${dest}"
  term_notify "linuxbkup" "Backup complete → ${dest}"
}
