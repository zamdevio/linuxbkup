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
  # shellcheck source=lib/backup/reinstall.sh
  source "${LINUXBKUP_ROOT}/lib/backup/reinstall.sh"

  local reinstall_only="${LINUXBKUP_REINSTALL_ONLY:-0}"
  if [[ "${reinstall_only}" -eq 1 && "${LINUXBKUP_SKIP_REINSTALL:-0}" -eq 1 ]]; then
    log_fatal "cannot combine --reinstall-only with --skip-reinstall"
    return 2
  fi

  local desc="Reconstruct environment from a backup (extract → secrets → files → reinstalls)."
  [[ "${reinstall_only}" -eq 1 ]] && desc="Reinstall regenerables only (node_modules from manifest)."

  cmd_context_begin restore \
    --desc "${desc}" \
    --required tar zstd rsync sha256sum \
    --optional age openssl

  local kind="archive" root="" tmp="" extract_rc=0 dec_rc=0 files_rc=0
  local dest_home="${LINUXBKUP_HOME:-${HOME:-}}"
  local dest_user=""
  local _pf_rc=0
  local steps=5
  [[ "${reinstall_only}" -eq 1 ]] && steps=3
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
  [[ "${LINUXBKUP_SKIP_REINSTALL:-0}" -eq 1 ]] && ui_kv "Reinstalls" "skipped (--skip-reinstall)"
  [[ "${reinstall_only}" -eq 1 ]] && ui_kv "Mode" "reinstall-only"
  if env_sudo_user_remap; then
    log_info "sudo detected — home/secrets → ${dest_user} (${dest_home}); /etc when writable"
  fi

  # Peek reinstalls.tsv only (no full extract) → guide PM installs immediately
  if [[ "${LINUXBKUP_SKIP_REINSTALL:-0}" -ne 1 && "${LINUXBKUP_DRY_RUN:-0}" -ne 1 ]]; then
    set +e
    reinstall_preflight_guide "${backup}" "${kind}"
    _pf_rc=$?
    set -e
    case "${_pf_rc}" in
      0) ;;
      2) ui_kv "Reinstalls" "skipped (preflight)" ;;
      *)
        linuxbkup_events_end
        linuxbkup_op_end
        return 1
        ;;
    esac
  fi

  # --- extract / open stage -------------------------------------------------
  if [[ "${kind}" == "staging" ]]; then
    root="${backup}"
    ui_step_event 1 "${steps}" "extract" "extract — unpack archive"
    log_ok "using staging directory — no extract"
    linuxbkup_event skip extract "reason=staging"
  else
    if [[ "${LINUXBKUP_DRY_RUN:-0}" -eq 1 ]]; then
      log_info "dry-run — would extract and run restore steps"
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
    if [[ "${reinstall_only}" -eq 1 ]]; then
      # Manifest only — much faster than full home extract
      linuxbkup_without_monitor bash -c \
        "zstd -dcq \"${backup}\" | tar --warning=no-timestamp -C \"${tmp}\" -xf - packages"
    else
      linuxbkup_without_monitor bash -c \
        "zstd -dcq \"${backup}\" | tar --warning=no-timestamp -C \"${tmp}\" -xf -"
    fi
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

  if [[ "${reinstall_only}" -ne 1 ]]; then
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

    ui_step_event 4 "${steps}" "reinstall" "reinstall — node_modules from manifest"
  else
    ui_step_event 2 "${steps}" "reinstall" "reinstall — node_modules from manifest"
  fi

  linuxbkup_op_begin "restore-reinstall" "${root}" 0 1
  set +e
  reinstall_apply "${root}" "${dest_home}"
  set -e
  linuxbkup_event ok reinstall
  linuxbkup_op_end

  if [[ "${reinstall_only}" -eq 1 ]]; then
    ui_step_event 3 "${steps}" "report" "report — restore status"
  else
    ui_step_event 5 "${steps}" "report" "report — restore status"
  fi
  ui_section "Restore status"
  if [[ "${reinstall_only}" -eq 1 ]]; then
    ui_kv "Mode" "reinstall-only (home/config not re-copied)"
  elif [[ -d "${root}/home" ]]; then
    ui_kv_path "Staged home" "${root}/home"
    ui_kv_path "Applied to" "${dest_home}"
  else
    ui_kv "Home tree" "missing in backup"
  fi
  if [[ -f "${root}/packages/reinstalls.json" ]]; then
    ui_kv_path "Reinstalls" "${root}/packages/reinstalls.json"
  fi
  if [[ -f "${root}/packages/apt.manual" && "${reinstall_only}" -ne 1 ]]; then
    ui_kv_path "APT manuals" "${root}/packages/apt.manual"
    ui_item note "APT package reinstall not applied yet — manifests only."
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
