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
    classify|checksum|pack|plan|inspect|verify|verify-extract|index|secrets|apt-capture|snapshot)
      return 0
      ;;
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
  # New step = accept Ctrl+C again (resolve leaves INT ignored through retry setup).
  linuxbkup_interrupt_arm
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

# Ignore SIGINT (teardown / resume windows). Pair with linuxbkup_interrupt_arm.
linuxbkup_interrupt_disarm() {
  trap '' INT
}

linuxbkup_interrupt_arm() {
  if declare -F safety_on_int >/dev/null 2>&1; then
    trap 'safety_on_int' INT
  fi
}

# Defer SIGINT around short critical work (avoids empty $(…) after coalesced Ctrl+C).
linuxbkup_interrupt_shield() {
  linuxbkup_interrupt_disarm
  "$@"
  local _shield_rc=$?
  linuxbkup_interrupt_arm
  return "${_shield_rc}"
}

# Run a blocking command/pipeline with monitor mode OFF so tty Ctrl+C hits
# our SIGINT trap (not only a child PGID). Restores set -m afterward.
# Usage: linuxbkup_without_monitor tar ... \| zstd ...   — or a function.
linuxbkup_without_monitor() {
  local had_m=0 _rc=0
  [[ $- == *m* ]] && had_m=1
  set +m 2>/dev/null || true
  "$@"
  _rc=$?
  [[ "${had_m}" -eq 1 ]] && set -m 2>/dev/null || true
  return "${_rc}"
}

linuxbkup_interrupt_clear() {
  LINUXBKUP_WAS_INTERRUPTED=0
  LINUXBKUP_INTERRUPT_ACTION=""
  LINUXBKUP_OP_REDO=0
  LINUXBKUP_INTERRUPT_RESULT=""
}

_interrupt_read() {
  local prompt="$1" reply=""
  # Test hook — smoke injects r/s/c/q without a real TTY dance.
  if [[ -n "${LINUXBKUP_TEST_INTERRUPT_REPLY:-}" ]]; then
    printf '%s\n' "${LINUXBKUP_TEST_INTERRUPT_REPLY}"
    return 0
  fi
  # Prompt + read on the real tty (fish/job-control can swallow stdout traps).
  if { [[ -c /dev/tty ]] && printf '%s' "${prompt}" >/dev/tty; } 2>/dev/null; then
    read -r reply </dev/tty || reply=""
  elif [[ -t 0 ]]; then
    read -r -p "${prompt}" reply || true
  else
    reply=""
  fi
  printf '%s\n' "${reply}"
}

# Write menu/prompt text to the real terminal first; stderr only if no tty.
# Fish + SIGINT traps often drop stdout — never rely on it for the menu body.
_interrupt_tty() {
  local msg="$1"
  if { [[ -c /dev/tty ]] && printf '%s' "${msg}" >/dev/tty; } 2>/dev/null; then
    return 0
  fi
  printf '%s' "${msg}" >&2
}

# ui_* helpers forced onto /dev/tty so fish traps stay visible (backup look).
_interrupt_ui_section() {
  if { [[ -c /dev/tty ]] && ui_section "$1" >/dev/tty; } 2>/dev/null; then
    return 0
  fi
  ui_section "$1"
}
_interrupt_ui_kv() {
  if { [[ -c /dev/tty ]] && ui_kv "$1" "$2" >/dev/tty; } 2>/dev/null; then
    return 0
  fi
  ui_kv "$1" "$2"
}

# Sets LINUXBKUP_INTERRUPT_ACTION. Safe from trap or after rsync rc=20.
# Same look as backup: ui_section "Interrupted" + ui_kv Step/Item + What next?
# Body forced to /dev/tty so it is visible mid-PM install.
linuxbkup_interrupt_menu() {
  local reply="" def="q"
  local can_skip="${LINUXBKUP_OP_CAN_SKIP:-0}"
  local can_retry="${LINUXBKUP_OP_CAN_RETRY:-1}"
  local applied=""

  declare -F term_live_park >/dev/null 2>&1 && term_live_park
  declare -F term_cursor_show >/dev/null 2>&1 && term_cursor_show

  if ! { printf '\n' >/dev/tty; } 2>/dev/null; then
    printf '\n' >&2
  fi
  _interrupt_ui_section "Interrupted"
  if [[ -n "${LINUXBKUP_OP_STEP:-}" ]]; then
    _interrupt_ui_kv "Step" "${LINUXBKUP_OP_STEP}"
  fi
  if [[ -n "${LINUXBKUP_OP_ITEM:-}" ]]; then
    _interrupt_ui_kv "Item" "${LINUXBKUP_OP_ITEM}"
  fi
  if [[ -n "${REINSTALL_BATCH_IDX:-}" && "${REINSTALL_BATCH_TOTAL:-0}" -gt 0 ]]; then
    _interrupt_ui_kv "Project" "[${REINSTALL_BATCH_IDX}/${REINSTALL_BATCH_TOTAL}]"
  fi
  if [[ "${LINUXBKUP_INTERRUPT_SOFT_QUIT:-0}" -eq 1 ]]; then
    _interrupt_ui_kv "Mode" "reinstall batch (q = stop batch, not whole restore)"
  fi

  _interrupt_tty $'\n  What next?\n'
  if [[ "${can_retry}" -eq 1 ]]; then
    _interrupt_tty $'    [r] Retry last operation (overwrite / re-run; discards partial)\n'
  fi
  if [[ "${can_skip}" -eq 1 && -n "${LINUXBKUP_OP_ITEM:-}" ]]; then
    _interrupt_tty $'    [s] Skip this item and continue\n'
    _interrupt_tty $'    [c] Skip this item and continue (same as s)\n'
  elif _linuxbkup_op_needs_full_retry; then
    _interrupt_tty $'    [c] Same as retry (partial results are unsafe to keep)\n'
  else
    _interrupt_tty $'    [c] Continue from here\n'
  fi
  if [[ "${LINUXBKUP_INTERRUPT_SOFT_QUIT:-0}" -eq 1 ]]; then
    _interrupt_tty $'    [q] Quit reinstall batch (partial summary; restore continues)\n'
  else
    _interrupt_tty $'    [q] Quit command (keep staging / partial work)\n'
  fi
  if [[ -n "${LINUXBKUP_BACKUP_STAGE:-}" && -d "${LINUXBKUP_BACKUP_STAGE:-}" ]]; then
    _interrupt_tty $'    [x] Quit and remove staging\n'
  fi
  _interrupt_tty $'\n'

  while true; do
    reply="$(_interrupt_read "Choice [r/s/c/q/x] (default q): ")"
    if [[ -z "${reply}" && -z "${LINUXBKUP_TEST_INTERRUPT_REPLY:-}" ]]; then
      _interrupt_tty $'  (empty) — menu above. Enter again, or type r/s/c/q\n'
      _interrupt_tty $'  Choice [r/s/c/q/x] (default q): '
      if [[ -c /dev/tty ]]; then
        read -r reply </dev/tty || reply=""
      else
        read -r reply || reply=""
      fi
      reply="${reply:-}"
    fi
    reply="${reply:-${def}}"
    case "${reply}" in
      r|R|retry)
        if [[ "${can_retry}" -ne 1 ]]; then
          _interrupt_tty $'  Retry not available for this step — pick c/q\n'
          continue
        fi
        LINUXBKUP_INTERRUPT_ACTION="retry"
        LINUXBKUP_OP_REDO=1
        break
        ;;
      s|S|skip)
        if [[ "${can_skip}" -ne 1 || -z "${LINUXBKUP_OP_ITEM:-}" ]]; then
          _interrupt_tty $'  Skip not available here — pick r/c/q\n'
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
      q|Q|quit)
        LINUXBKUP_INTERRUPT_ACTION="quit"
        break
        ;;
      x|X)
        LINUXBKUP_INTERRUPT_ACTION="quit_clean"
        break
        ;;
      *)
        _interrupt_tty $'  Unknown choice — use r, s, c, q, or x\n'
        ;;
    esac
  done

  applied="${LINUXBKUP_INTERRUPT_ACTION}"
  _interrupt_tty "  → applied: ${applied}"$'\n\n'
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
      # Soft-quit (reinstall batch): stop the batch, print partial summary —
      # never exit 130 the whole restore process.
      if [[ "${LINUXBKUP_INTERRUPT_SOFT_QUIT:-0}" -eq 1 ]]; then
        LINUXBKUP_INTERRUPT_RESULT="quit"
        log_info "Interrupted — stopping reinstall batch after this project"
        return 0
      fi
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
      if [[ "${LINUXBKUP_INTERRUPT_SOFT_QUIT:-0}" -eq 1 ]]; then
        LINUXBKUP_INTERRUPT_RESULT="quit"
        log_info "Interrupted — stopping reinstall batch after this project"
        return 0
      fi
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
# Leaves SIGINT ignored — caller must linuxbkup_interrupt_arm before the next
# long wait (or arm is deferred until after retry setup).
linuxbkup_interrupt_resolve() {
  LINUXBKUP_INTERRUPT_RESULT=""
  if ! linuxbkup_interrupt_pending; then
    return 1
  fi
  linuxbkup_interrupt_disarm
  if [[ -z "${LINUXBKUP_INTERRUPT_ACTION:-}" ]]; then
    # Second Ctrl+C during post-syscall menu → hard quit
    trap 'log_fatal "Interrupted (forced)"; exit 130' INT
    linuxbkup_interrupt_menu
    linuxbkup_interrupt_disarm
  fi
  linuxbkup_interrupt_apply
  # Reap stragglers; keep INT ignored so monitor-mode job notifications
  # cannot re-raise SIGINT and kill the shell mid-retry.
  wait 2>/dev/null || true
  return 0
}
