# shellcheck shell=bash

linuxbkup_cmd_restore() {
  if cmd_want_help "$@"; then
    linuxbkup_cmd_help restore
    return 0
  fi

  local backup="${1:-}"
  if [[ -z "${backup}" ]]; then
    log_fatal "Usage: linuxbkup restore <backup.tar.zst|staging-dir>"
    linuxbkup_cmd_help restore
    return 2
  fi

  # shellcheck source=lib/core/context.sh
  source "${LINUXBKUP_ROOT}/lib/core/context.sh"
  # shellcheck source=lib/archive/verify.sh
  source "${LINUXBKUP_ROOT}/lib/archive/verify.sh"
  # shellcheck source=lib/backup/secrets_crypt.sh
  source "${LINUXBKUP_ROOT}/lib/backup/secrets_crypt.sh"

  cmd_context_begin restore \
    --desc "Reconstruct environment from a backup (secrets decrypt live; home copy later)." \
    --required tar zstd rsync sha256sum \
    --optional age openssl

  local kind="archive" root="" tmp="" extract_rc=0 dec_rc=0

  if [[ -d "${backup}" ]]; then
    kind="staging"
  elif [[ -f "${backup}" ]]; then
    kind="archive"
  else
    log_fatal "not a file or directory: ${backup}"
    return 2
  fi

  linuxbkup_events_begin ""
  linuxbkup_op_begin "restore" "${backup}" 0 1
  ui_kv "Source" "${kind}"
  ui_kv_path "Backup" "${backup}"

  if [[ "${kind}" == "staging" ]]; then
    root="${backup}"
    log_ok "using staging directory — no extract"
  else
    if [[ "${LINUXBKUP_DRY_RUN:-0}" -eq 1 ]]; then
      log_info "dry-run — would extract archive and decrypt secrets if present"
      linuxbkup_op_end
      linuxbkup_events_end
      return 0
    fi
    tmp="$(mktemp -d "${TMPDIR:-/tmp}/linuxbkup-restore.XXXXXX")"
    LINUXBKUP_RESTORE_TMP="${tmp}"
    _linuxbkup_restore_on_exit() {
      declare -F linuxbkup_tty_restore >/dev/null 2>&1 && linuxbkup_tty_restore
      if [[ "${LINUXBKUP_KEEP_STAGE:-0}" -eq 1 ]]; then
        [[ -n "${LINUXBKUP_RESTORE_TMP:-}" && -d "${LINUXBKUP_RESTORE_TMP}" ]] \
          && log_info "keeping extract: ${LINUXBKUP_RESTORE_TMP}"
        return 0
      fi
      rm -rf "${LINUXBKUP_RESTORE_TMP:-}"
    }
    trap '_linuxbkup_restore_on_exit' EXIT

    ui_step_event 1 3 "extract" "extract — unpack archive"
    linuxbkup_op_begin "restore-extract" "${backup}" 0 1
    set +e
    linuxbkup_without_monitor bash -c "zstd -dcq \"${backup}\" | tar -C \"${tmp}\" -xf -"
    extract_rc=$?
    set -e
    if linuxbkup_interrupt_pending || [[ "${extract_rc}" -ne 0 && "${LINUXBKUP_WAS_INTERRUPTED:-0}" -eq 1 ]]; then
      LINUXBKUP_WAS_INTERRUPTED=1
      linuxbkup_interrupt_resolve
      case "${LINUXBKUP_INTERRUPT_RESULT}" in
        retry|continue|skip)
          rm -rf "${tmp}"
          trap - EXIT
          linuxbkup_op_end
          linuxbkup_cmd_restore "${backup}"
          return $?
          ;;
        *) return 1 ;;
      esac
    fi
    if [[ "${extract_rc}" -ne 0 ]]; then
      linuxbkup_event fail extract
      log_fatal "failed to extract archive"
      return 1
    fi
    linuxbkup_event ok extract
    root="${tmp}"
    log_ok "extracted to ${tmp}"
    linuxbkup_op_end
  fi

  if declare -F archive_verify_schema >/dev/null 2>&1; then
    archive_verify_schema "${root}"
  fi

  ui_step_event 2 3 "secrets" "secrets — decrypt if encrypted"
  linuxbkup_op_begin "restore-secrets" "${root}" 0 1
  set +e
  backup_secrets_decrypt_stage "${root}"
  dec_rc=$?
  set -e
  case "${dec_rc}" in
    0) linuxbkup_event ok secrets ;;
    2)
      linuxbkup_event skip secrets "reason=none"
      log_info "no encrypted secrets to decrypt"
      ;;
    *)
      linuxbkup_event fail secrets
      linuxbkup_op_end
      return 1
      ;;
  esac
  linuxbkup_op_end

  ui_step_event 3 3 "report" "report — restore status"
  ui_section "Restore status"
  if [[ -d "${root}/home" ]]; then
    ui_kv "Home tree" "present (file restore not wired yet)"
    ui_kv_path "Staged home" "${root}/home"
  else
    ui_kv "Home tree" "missing"
  fi
  if [[ -d "${root}/secrets" ]]; then
    ui_kv_path "Secrets" "${root}/secrets"
    log_ok "secrets ready under extract/staging"
  elif [[ -f "${root}/secrets.tar.age" ]]; then
    ui_kv "Secrets" "still encrypted (decrypt failed or skipped)"
  else
    ui_kv "Secrets" "none in backup"
  fi
  if [[ -f "${root}/packages/apt.manual" ]]; then
    ui_kv_path "APT manuals" "${root}/packages/apt.manual"
  fi
  ui_item note "Full home/config restore lands next on the restore Focus."
  if [[ -n "${tmp:-}" && "${LINUXBKUP_KEEP_STAGE:-0}" -eq 1 ]]; then
    ui_kv_path "Extract kept" "${tmp}"
  fi

  linuxbkup_event ok report
  linuxbkup_events_end
  linuxbkup_op_end
  log_ok "restore secrets path complete"
  return 0
}
