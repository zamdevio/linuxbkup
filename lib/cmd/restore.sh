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
  # shellcheck source=lib/backup/restore_files.sh
  source "${LINUXBKUP_ROOT}/lib/backup/restore_files.sh"

  cmd_context_begin restore \
    --desc "Reconstruct environment from a backup (extract → secrets → home/config)." \
    --required tar zstd rsync sha256sum \
    --optional age openssl

  local kind="archive" root="" tmp="" extract_rc=0 dec_rc=0 files_rc=0
  local dest_home="${LINUXBKUP_HOME:-${HOME:-}}"
  local dest_user=""
  local steps=4
  # shellcheck source=lib/env/users.sh
  source "${LINUXBKUP_ROOT}/lib/env/users.sh"
  dest_user="$(env_resolve_user)"
  if ! dest_home="$(env_user_home "${dest_user}")"; then
    dest_home="${LINUXBKUP_HOME:-/home/${dest_user}}"
  fi
  LINUXBKUP_HOME="${dest_home}"
  export LINUXBKUP_HOME

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
  ui_kv_path "Target home" "${dest_home}"
  ui_kv "Target user" "${dest_user}"
  if env_sudo_user_remap; then
    log_info "sudo detected — home/secrets → ${dest_user} (${dest_home}); /etc when writable"
  fi

  if [[ "${kind}" == "staging" ]]; then
    root="${backup}"
    ui_step_event 1 "${steps}" "extract" "extract — unpack archive"
    log_ok "using staging directory — no extract"
    linuxbkup_event skip extract "reason=staging"
  else
    if [[ "${LINUXBKUP_DRY_RUN:-0}" -eq 1 ]]; then
      log_info "dry-run — would extract, decrypt secrets, and rsync home/config"
      ui_step_event 1 "${steps}" "extract" "extract — unpack archive"
      linuxbkup_event skip extract "reason=dry-run"
      ui_step_event 2 "${steps}" "secrets" "secrets — decrypt if encrypted"
      linuxbkup_event skip secrets "reason=dry-run"
      ui_step_event 3 "${steps}" "files" "files — home / secrets / config"
      # Best-effort: peek archive listing is expensive; just report intent
      ui_kv "files" "would rsync home+secrets → ${dest_home}/ and config → /etc"
      linuxbkup_event skip files "reason=dry-run"
      ui_step_event 4 "${steps}" "report" "report — restore status"
      linuxbkup_event ok report
      linuxbkup_events_end
      linuxbkup_op_end
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

    ui_step_event 1 "${steps}" "extract" "extract — unpack archive"
    linuxbkup_op_begin "restore-extract" "${backup}" 0 1
    set +e
    # --warning=no-timestamp: ignore absurd mtimes in staged trees (noise on extract)
    linuxbkup_without_monitor bash -c \
      "zstd -dcq \"${backup}\" | tar --warning=no-timestamp -C \"${tmp}\" -xf -"
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

  ui_step_event 2 "${steps}" "secrets" "secrets — decrypt if encrypted"
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

  ui_step_event 3 "${steps}" "files" "files — home / secrets / config"
  linuxbkup_op_begin "restore-files" "${root}" 0 1
  set +e
  restore_files_apply "${root}" "${dest_home}" "${dest_user}"
  files_rc=$?
  set -e
  if [[ "${files_rc}" -ne 0 ]]; then
    linuxbkup_event fail files
    linuxbkup_op_end
    return 1
  fi
  linuxbkup_event ok files
  linuxbkup_op_end

  ui_step_event 4 "${steps}" "report" "report — restore status"
  ui_section "Restore status"
  if [[ -d "${root}/home" ]]; then
    ui_kv_path "Staged home" "${root}/home"
    ui_kv_path "Applied to" "${dest_home}"
  else
    ui_kv "Home tree" "missing in backup"
  fi
  if [[ -d "${root}/secrets" ]]; then
    ui_kv_path "Secrets (staged)" "${root}/secrets"
  elif [[ -f "${root}/secrets.tar.age" ]]; then
    ui_kv "Secrets" "still encrypted (decrypt failed or skipped)"
  else
    ui_kv "Secrets" "none in backup"
  fi
  if [[ -d "${root}/config/etc" ]]; then
    ui_kv_path "Staged config" "${root}/config/etc"
  fi
  if [[ -f "${root}/packages/apt.manual" ]]; then
    ui_kv_path "APT manuals" "${root}/packages/apt.manual"
    ui_item note "Package reinstall modules are not applied yet — manifests only."
  fi
  if [[ -n "${tmp:-}" && "${LINUXBKUP_KEEP_STAGE:-0}" -eq 1 ]]; then
    ui_kv_path "Extract kept" "${tmp}"
  fi

  linuxbkup_event ok report
  linuxbkup_events_end
  linuxbkup_op_end
  log_ok "restore complete"
  return 0
}
