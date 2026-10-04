# shellcheck shell=bash
# Ctrl+C: pause → menu → retry | skip | continue | quit. Ops use interrupt_resolve.

LINUXBKUP_OP_STEP="${LINUXBKUP_OP_STEP:-}"
LINUXBKUP_OP_ITEM="${LINUXBKUP_OP_ITEM:-}"
LINUXBKUP_OP_CAN_SKIP="${LINUXBKUP_OP_CAN_SKIP:-0}"
LINUXBKUP_OP_CAN_RETRY="${LINUXBKUP_OP_CAN_RETRY:-1}"

LINUXBKUP_WAS_INTERRUPTED=0
LINUXBKUP_INTERRUPT_ACTION="" # retry|skip|continue|quit|quit_clean
LINUXBKUP_INT_BUSY=0
LINUXBKUP_OP_REDO=0 # 1 = re-run step; discard partial

# Steps where "continue" must not keep partial results (copy uses skip instead).
_linuxbkup_op_needs_full_retry() {
  case "${LINUXBKUP_OP_STEP:-}" in
    classify|checksum|pack|plan|inspect|verify|verify-extract) return 0 ;;
    *) return 1 ;;
  esac
}

# Args: step [item] [can_skip=0|1] [can_retry=1]
linuxbkup_op_begin() {
  LINUXBKUP_OP_STEP="${1:-}"
  LINUXBKUP_OP_ITEM="${2:-}"
  LINUXBKUP_OP_CAN_SKIP="${3:-0}"
  LINUXBKUP_OP_CAN_RETRY="${4:-1}"
  LINUXBKUP_WAS_INTERRUPTED=0
  LINUXBKUP_INTERRUPT_ACTION=""
  LINUXBKUP_OP_REDO=0
}

linuxbkup_op_item() {
  LINUXBKUP_OP_ITEM="${1:-}"
}

linuxbkup_op_end() {
  LINUXBKUP_OP_STEP=""
  LINUXBKUP_OP_ITEM=""
  LINUXBKUP_OP_CAN_SKIP=0
  LINUXBKUP_OP_CAN_RETRY=1
  LINUXBKUP_OP_REDO=0
}

linuxbkup_interrupt_pending() {
  [[ "${LINUXBKUP_WAS_INTERRUPTED:-0}" -eq 1 || -n "${LINUXBKUP_INTERRUPT_ACTION:-}" || "${LINUXBKUP_OP_REDO:-0}" -eq 1 ]]
}

# Defer SIGINT around short critical work (avoids empty $(…) after coalesced Ctrl+C).
linuxbkup_interrupt_shield() {
  trap '' INT
  "$@"
  local _shield_rc=$?
  trap 'safety_on_int' INT
  return "${_shield_rc}"
}

linuxbkup_interrupt_clear() {
  LINUXBKUP_WAS_INTERRUPTED=0
  LINUXBKUP_INTERRUPT_ACTION=""
  LINUXBKUP_OP_REDO=0
  LINUXBKUP_INTERRUPT_RESULT=""
}

_interrupt_read() {
  local prompt="$1" reply=""
  if [[ -c /dev/tty ]]; then
    read -r -p "${prompt}" reply </dev/tty || true
  elif [[ -t 0 ]]; then
    read -r -p "${prompt}" reply || true
  else
    reply=""
  fi
  printf '%s\n' "${reply}"
}

# Sets LINUXBKUP_INTERRUPT_ACTION. Safe from trap or after rsync rc=20.
linuxbkup_interrupt_menu() {
  local reply="" def="q"
  local can_skip="${LINUXBKUP_OP_CAN_SKIP:-0}"
  local can_retry="${LINUXBKUP_OP_CAN_RETRY:-1}"

  declare -F term_live_park >/dev/null 2>&1 && term_live_park
  declare -F term_cursor_show >/dev/null 2>&1 && term_cursor_show
  printf '\n' >&2
  ui_section "Interrupted" 2>/dev/null || printf 'Interrupted\n' >&2
  if [[ -n "${LINUXBKUP_OP_STEP:-}" ]]; then
    ui_kv "Step" "${LINUXBKUP_OP_STEP}" 2>/dev/null || printf '  Step: %s\n' "${LINUXBKUP_OP_STEP}" >&2
  fi
  if [[ -n "${LINUXBKUP_OP_ITEM:-}" ]]; then
    ui_kv "Item" "${LINUXBKUP_OP_ITEM}" 2>/dev/null || printf '  Item: %s\n' "${LINUXBKUP_OP_ITEM}" >&2
  fi
  printf '\n' >&2
  printf '  What next?\n' >&2
  if [[ "${can_retry}" -eq 1 ]]; then
    printf '    [r] Retry last operation (overwrite / re-run; discards partial)\n' >&2
  fi
  if [[ "${can_skip}" -eq 1 && -n "${LINUXBKUP_OP_ITEM:-}" ]]; then
    printf '    [s] Skip this item and continue\n' >&2
    printf '    [c] Skip this item and continue (same as s)\n' >&2
  elif _linuxbkup_op_needs_full_retry; then
    printf '    [c] Same as retry (partial results are unsafe to keep)\n' >&2
  else
    printf '    [c] Continue from here\n' >&2
  fi
  printf '    [q] Quit command (keep staging / partial work)\n' >&2
  if [[ -n "${LINUXBKUP_BACKUP_STAGE:-}" && -d "${LINUXBKUP_BACKUP_STAGE:-}" ]]; then
    printf '    [x] Quit and remove staging\n' >&2
  fi
  printf '\n' >&2

  while true; do
    reply="$(_interrupt_read "Choice [r/s/c/q/x] (default q): ")"
    reply="${reply:-${def}}"
    case "${reply}" in
      r|R|retry)
        if [[ "${can_retry}" -ne 1 ]]; then
          printf '  Retry not available for this step — pick c/q\n' >&2
          continue
        fi
        LINUXBKUP_INTERRUPT_ACTION="retry"
        LINUXBKUP_OP_REDO=1
        break
        ;;
      s|S|skip)
        if [[ "${can_skip}" -ne 1 || -z "${LINUXBKUP_OP_ITEM:-}" ]]; then
          printf '  Skip not available here — pick r/c/q\n' >&2
          continue
        fi
        LINUXBKUP_INTERRUPT_ACTION="skip"
        break
        ;;
      c|C|cont|continue)
        if [[ "${can_skip}" -eq 1 && -n "${LINUXBKUP_OP_ITEM:-}" ]]; then
          LINUXBKUP_INTERRUPT_ACTION="skip"
        elif _linuxbkup_op_needs_full_retry; then
          LINUXBKUP_INTERRUPT_ACTION="retry"
          LINUXBKUP_OP_REDO=1
        else
          LINUXBKUP_INTERRUPT_ACTION="continue"
        fi
        break
        ;;
      q|Q|quit|"")
        LINUXBKUP_INTERRUPT_ACTION="quit"
        break
        ;;
      x|X)
        LINUXBKUP_INTERRUPT_ACTION="quit_clean"
        break
        ;;
      *)
        printf '  Unknown choice — use r, s, c, q, or x\n' >&2
        ;;
    esac
  done

  log_verbose "interrupt action=${LINUXBKUP_INTERRUPT_ACTION}"
}

# Last apply result (retry|skip|continue). Never read via $(apply) — subshell
# would leave ACTION sticky in the parent.
LINUXBKUP_INTERRUPT_RESULT=""

# Apply quit_* (exit) or clear flags in the current shell. Do not wrap in $().
linuxbkup_interrupt_apply() {
  local action="${LINUXBKUP_INTERRUPT_ACTION:-quit}"
  LINUXBKUP_WAS_INTERRUPTED=0
  LINUXBKUP_INTERRUPT_ACTION=""
  LINUXBKUP_INTERRUPT_RESULT=""

  case "${action}" in
    quit)
      declare -F linuxbkup_tty_restore >/dev/null 2>&1 && linuxbkup_tty_restore
      log_fatal "Interrupted — quitting (staging kept if any)"
      if [[ -n "${LINUXBKUP_BACKUP_STAGE:-}" && -d "${LINUXBKUP_BACKUP_STAGE}" ]]; then
        log_info "Staging: ${LINUXBKUP_BACKUP_STAGE}"
        log_info "Verify:  linuxbkup verify ${LINUXBKUP_BACKUP_STAGE}"
        log_info "Remove:  rm -rf ${LINUXBKUP_BACKUP_STAGE}"
      fi
      exit 130
      ;;
    quit_clean)
      declare -F linuxbkup_tty_restore >/dev/null 2>&1 && linuxbkup_tty_restore
      if [[ -n "${LINUXBKUP_BACKUP_STAGE:-}" && -d "${LINUXBKUP_BACKUP_STAGE}" ]]; then
        if declare -F backup_stage_cleanup >/dev/null 2>&1; then
          LINUXBKUP_KEEP_STAGE=0
          backup_stage_cleanup "${LINUXBKUP_BACKUP_STAGE}"
        else
          rm -rf "${LINUXBKUP_BACKUP_STAGE}"
        fi
        LINUXBKUP_BACKUP_STAGE=""
        log_info "Staging removed"
      fi
      log_fatal "Interrupted — quit and cleaned up"
      exit 130
      ;;
    retry|skip|continue)
      if [[ -n "${TERM_PROGRESS_T0+x}" ]]; then
        TERM_PROGRESS_T0="$(date +%s)"
      fi
      if [[ "${TERM_PROGRESS_ACTIVE:-0}" -eq 1 ]]; then
        declare -F term_cursor_hide >/dev/null 2>&1 && term_cursor_hide
      fi
      if [[ "${action}" == "retry" ]]; then
        LINUXBKUP_OP_REDO=1
        log_info "Retrying last operation (overwrite partial)…"
      else
        log_info "Resuming (${action})…"
      fi
      LINUXBKUP_INTERRUPT_RESULT="${action}"
      return 0
      ;;
    *)
      log_fatal "Interrupted"
      exit 130
      ;;
  esac
}

# Central path for ops after a long step returns.
# return 1 = nothing pending; return 0 = RESULT is retry|skip|continue;
# exit 130 = quit. Never wrap in $().
linuxbkup_interrupt_resolve() {
  LINUXBKUP_INTERRUPT_RESULT=""
  if ! linuxbkup_interrupt_pending; then
    return 1
  fi
  if [[ -z "${LINUXBKUP_INTERRUPT_ACTION:-}" ]]; then
    linuxbkup_interrupt_menu
  fi
  linuxbkup_interrupt_apply
  # Drop coalesced SIGINT from child teardown before retry
  if declare -F safety_on_int >/dev/null 2>&1; then
    trap '' INT
    trap 'safety_on_int' INT
  fi
  return 0
}
