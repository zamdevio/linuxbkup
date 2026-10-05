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
  # shellcheck source=lib/env/snapshot.sh
  source "${LINUXBKUP_ROOT}/lib/env/snapshot.sh"
  # shellcheck source=lib/core/platform/paths.sh
  source "${LINUXBKUP_ROOT}/lib/core/platform/paths.sh"
  # shellcheck source=lib/backup/stage.sh
  source "${LINUXBKUP_ROOT}/lib/backup/stage.sh"
  # shellcheck source=lib/backup/home.sh
  source "${LINUXBKUP_ROOT}/lib/backup/home.sh"
  # shellcheck source=lib/backup/secrets_crypt.sh
  source "${LINUXBKUP_ROOT}/lib/backup/secrets_crypt.sh"
  # shellcheck source=lib/backup/preflight.sh
  source "${LINUXBKUP_ROOT}/lib/backup/preflight.sh"
  # shellcheck source=lib/backup/schema.sh
  source "${LINUXBKUP_ROOT}/lib/backup/schema.sh"
  # shellcheck source=modules/apt.sh
  source "${LINUXBKUP_ROOT}/modules/apt.sh"
  # shellcheck source=lib/archive/checksums.sh
  source "${LINUXBKUP_ROOT}/lib/archive/checksums.sh"
  # shellcheck source=lib/archive/pack.sh
  source "${LINUXBKUP_ROOT}/lib/archive/pack.sh"
  # shellcheck source=lib/classify/plan.sh
  source "${LINUXBKUP_ROOT}/lib/classify/plan.sh"

  LINUXBKUP_PERM_SKIPS=0

  local user home stage dest dest_dir snap_action=""

  # Resolve identity + archive path BEFORE the tools banner so a Ctrl+C during
  # setup cannot leave dest="" (dirname "" → "." → zstd writing nowhere).
  linuxbkup_op_begin "resolve" "" 0 1
  user="$(linuxbkup_interrupt_shield env_resolve_user)"
  if ! home="$(linuxbkup_interrupt_shield env_user_home "${user}")"; then
    linuxbkup_op_end
    log_fatal "No home directory for user: ${user}"
    return 1
  fi
  LINUXBKUP_HOME="${home}"
  export LINUXBKUP_HOME

  if [[ -n "${LINUXBKUP_OUTPUT:-}" ]]; then
    dest="${LINUXBKUP_OUTPUT}"
  else
    dest="$(linuxbkup_interrupt_shield platform_default_archive_path)"
    # Coalesced SIGINT can abort $(…) to empty — retry once under shield
    if [[ -z "${dest}" ]]; then
      dest="$(linuxbkup_interrupt_shield platform_default_archive_path)"
    fi
  fi
  if [[ -z "${dest}" ]]; then
    linuxbkup_op_end
    log_fatal "could not resolve archive destination — pass -o/--output PATH"
    return 1
  fi
  dest_dir="$(dirname -- "${dest}")"
  LINUXBKUP_BACKUP_DEST="${dest}"
  export LINUXBKUP_BACKUP_DEST
  linuxbkup_op_end
  linuxbkup_interrupt_clear

  cmd_context_begin backup \
    --desc "Create an intelligent backup archive." \
    --required tar zstd rsync du sha256sum \
    --optional age

  log_verbose "backup target user=${user} home=${home}"
  log_debug "dest=${dest} dry_run=${LINUXBKUP_DRY_RUN:-0} yes=${LINUXBKUP_YES:-0}"

  # Backup pipeline: 7 labeled steps + structured events (09.5 / 08.10).
  local _bk_steps=7
  local _ev_tmp=""

  ui_heading "Backup"
  ui_kv_path "Home" "${home}"
  ui_kv_path "Destination" "${dest}"
  [[ "${LINUXBKUP_DRY_RUN:-0}" -eq 1 ]] && ui_kv "Mode" "dry-run"
  printf '\n'

  _ev_tmp="$(mktemp "${TMPDIR:-/tmp}/linuxbkup-events.XXXXXX")"
  linuxbkup_events_begin "${_ev_tmp}"

  # 09.1 + 09.4 — fail-fast + one-glance policy before heavy work
  ui_step_event 1 "${_bk_steps}" "preflight" "preflight — secrets, policy, disk"
  ui_section "Preflight"
  backup_preflight_banner
  if ! backup_secrets_preflight "${home}"; then
    linuxbkup_event fail preflight "reason=secrets"
    rm -f "${_ev_tmp}"
    return 1
  fi
  local stage_parent
  if [[ -n "${LINUXBKUP_STAGE_DIR:-}" ]]; then
    stage_parent="${LINUXBKUP_STAGE_DIR}"
  else
    stage_parent="${TMPDIR:-/tmp}"
  fi
  # Early floor check (full estimate runs again inside copy with real sizes)
  if [[ "${LINUXBKUP_DRY_RUN:-0}" -ne 1 ]]; then
    if ! backup_space_preflight "${dest}" "${stage_parent}" 0; then
      linuxbkup_event fail preflight "reason=space"
      rm -f "${_ev_tmp}"
      return 1
    fi
  fi
  linuxbkup_event ok preflight
  printf '\n'

  # 08.8 — detect (shared snapshot) after preflight clears
  ui_step_event 2 "${_bk_steps}" "detect" "detect — environment snapshot"
  while true; do
    linuxbkup_op_begin "snapshot" "" 0 1
    env_print_snapshot backup
    if linuxbkup_interrupt_resolve; then
      snap_action="${LINUXBKUP_INTERRUPT_RESULT}"
      case "${snap_action}" in
        retry) linuxbkup_op_end; continue ;;
        continue|skip) break ;;
        *)
          linuxbkup_op_end
          linuxbkup_event fail detect "reason=interrupt"
          rm -f "${_ev_tmp}"
          return 1
          ;;
      esac
    fi
    break
  done
  linuxbkup_op_end
  linuxbkup_event ok detect

  if [[ "${LINUXBKUP_DRY_RUN:-0}" -ne 1 ]]; then
    if ! safety_confirm "Proceed with backup?" "y"; then
      log_skip "backup cancelled"
      linuxbkup_event skip backup "reason=cancelled"
      rm -f "${_ev_tmp}"
      return 1
    fi
    if ! mkdir -p "${dest_dir}"; then
      log_fatal "cannot create ${dest_dir} — check permissions or pass --output <path>"
      linuxbkup_event fail backup "reason=dest_dir"
      rm -f "${_ev_tmp}"
      return 1
    fi
    log_ok "destination dir ready"
    ui_kv_path "Dir" "${dest_dir}"
  fi

  if [[ "${LINUXBKUP_DRY_RUN:-0}" -eq 1 ]]; then
    stage="/tmp/linuxbkup.dry-run.placeholder"
    log_info "dry-run — staging skipped (no files written)"
    linuxbkup_event ok dry_run
    backup_write_metadata "${stage}" "${user}" "${home}" || true
    apt_capture_manifests "${stage}" || true
    backup_copy_home "${home}" "${stage}" || true
    backup_secrets_encrypt_stage "${stage}" || true
    printf '\n'
    classify_print_backup_summary "${home}"
    printf '\n'
    log_ok "backup complete (dry-run)"
    rm -f "${_ev_tmp}"
    linuxbkup_events_end
    return 0
  fi

  stage="$(backup_stage_create)"
  LINUXBKUP_BACKUP_STAGE="${stage}"
  LINUXBKUP_BACKUP_OK=0
  log_ok "staging: ${stage}"
  log_debug "staging created at ${stage}"

  # Persist events into the stage (lands in the archive via pack).
  mkdir -p "${stage}/metadata"
  if [[ -n "${_ev_tmp}" && -f "${_ev_tmp}" ]]; then
    cat "${_ev_tmp}" >"${stage}/metadata/events.jsonl"
    rm -f "${_ev_tmp}"
    _ev_tmp=""
  else
    : >"${stage}/metadata/events.jsonl"
  fi
  LINUXBKUP_EVENTS_FILE="${stage}/metadata/events.jsonl"

  _linuxbkup_backup_on_exit() {
    local rc=$?
    # Replaces install_traps EXIT — always restore cursor here too
    declare -F linuxbkup_tty_restore >/dev/null 2>&1 && linuxbkup_tty_restore
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
  # INT/TSTP/TERM: process-wide handlers from linuxbkup_install_traps

  backup_write_metadata "${stage}" "${user}" "${home}"
  backup_write_schema "${stage}" "${user}" "${home}"

  ui_step_event 3 "${_bk_steps}" "capture" "capture — package manifests"
  linuxbkup_op_begin "apt-capture" "" 0 1
  apt_capture_manifests "${stage}"
  if linuxbkup_interrupt_resolve; then
    snap_action="${LINUXBKUP_INTERRUPT_RESULT}"
    case "${snap_action}" in
      retry)
        linuxbkup_op_end
        apt_capture_manifests "${stage}"
        ;;
      continue|skip) ;;
      *)
        linuxbkup_op_end
        linuxbkup_event fail capture "reason=interrupt"
        return 1
        ;;
    esac
  fi
  linuxbkup_op_end
  linuxbkup_event ok capture

  ui_step_event 4 "${_bk_steps}" "stage" "stage — classify + copy"
  if ! backup_copy_home "${home}" "${stage}"; then
    linuxbkup_event fail stage "reason=copy"
    log_fatal "home/config copy aborted"
    return 1
  fi
  linuxbkup_event ok stage

  ui_step_event 5 "${_bk_steps}" "seal" "seal — secrets, INDEX, checksums"
  linuxbkup_op_begin "secrets" "" 0 1
  if ! backup_secrets_encrypt_stage "${stage}"; then
    linuxbkup_op_end
    linuxbkup_event fail seal "reason=secrets"
    log_fatal "secrets encrypt step failed"
    return 1
  fi
  if linuxbkup_interrupt_resolve; then
    case "${LINUXBKUP_INTERRUPT_RESULT}" in
      retry)
        linuxbkup_op_end
        backup_secrets_encrypt_stage "${stage}" || true
        ;;
      continue|skip) ;;
      *)
        linuxbkup_op_end
        linuxbkup_event fail seal "reason=interrupt"
        return 1
        ;;
    esac
  fi
  linuxbkup_op_end

  ui_section "Staging summary"
  ui_kv "Size" "$(du -sh "${stage}" 2>/dev/null | awk '{print $1}')"
  ui_kv_path "Stage" "${stage}"
  printf '\n'

  linuxbkup_op_begin "index" "" 0 1
  if ! backup_write_index "${stage}"; then
    linuxbkup_op_end
    linuxbkup_event fail seal "reason=index"
    log_fatal "INDEX step failed"
    return 1
  fi
  if linuxbkup_interrupt_resolve; then
    case "${LINUXBKUP_INTERRUPT_RESULT}" in
      retry)
        linuxbkup_op_end
        backup_write_index "${stage}" || true
        ;;
      continue|skip) ;;
      *)
        linuxbkup_op_end
        linuxbkup_event fail seal "reason=interrupt"
        return 1
        ;;
    esac
  fi
  linuxbkup_op_end

  if ! archive_write_checksums "${stage}"; then
    linuxbkup_event fail seal "reason=checksum"
    log_fatal "checksum step failed"
    return 1
  fi
  linuxbkup_event ok seal

  ui_step_event 6 "${_bk_steps}" "pack" "pack — tar.zst archive"
  if [[ -z "${dest}" ]]; then
    linuxbkup_event fail pack "reason=empty_dest"
    log_fatal "archive destination is empty — pass -o/--output (refusing to pack)"
    return 1
  fi
  if ! archive_pack_tar_zst "${stage}" "${dest}"; then
    linuxbkup_event fail pack "reason=tar_zstd"
    log_fatal "archive pack failed"
    return 1
  fi
  linuxbkup_event ok pack "dest=${dest}"

  LINUXBKUP_BACKUP_OK=1
  if [[ "${LINUXBKUP_KEEP_STAGE:-0}" -eq 1 ]]; then
    log_info "keeping staging (--keep-stage): ${stage}"
    LINUXBKUP_BACKUP_STAGE=""
  else
    backup_stage_cleanup "${stage}"
    LINUXBKUP_BACKUP_STAGE=""
  fi
  # Drop staging EXIT handler only — keep INT/TERM until the command returns
  # so Ctrl+C during the summary still gets the menu (not raw SIGINT death).
  trap 'linuxbkup_tty_restore' EXIT

  ui_step_event 7 "${_bk_steps}" "summary" "summary"
  printf '\n'
  linuxbkup_op_begin "summary" "" 0 1
  classify_print_backup_summary "${home}"
  linuxbkup_op_end
  linuxbkup_event ok summary
  linuxbkup_events_end
  printf '\n'
  log_ok "backup complete"
  ui_kv_path "Archive" "${dest}"
  term_notify "linuxbkup" "Backup complete → ${dest}"
}
