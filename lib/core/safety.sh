# shellcheck shell=bash
# Confirmation, destructive-action gates, and signal handlers.

# Confirm a question. Returns 0 if approved.
# With LINUXBKUP_YES=1, accepts the provided default (safe path only).
# Usage: safety_confirm "Proceed with backup?" y
safety_confirm() {
  local prompt="$1"
  local default="${2:-n}" # y|n
  local reply

  if [[ "${LINUXBKUP_YES:-0}" -eq 1 ]]; then
    log_debug "auto-confirm (--yes): default=${default} :: ${prompt}"
    [[ "${default}" == "y" || "${default}" == "Y" ]]
    return $?
  fi

  if [[ ! -t 0 ]]; then
    log_fatal "Non-interactive stdin: pass --yes for safe defaults, or run in a TTY."
    return 1
  fi

  local hint="[y/N]"
  [[ "${default}" == "y" || "${default}" == "Y" ]] && hint="[Y/n]"

  # Prefer /dev/tty so Ctrl+C confirm still works if stdin was a pipe
  if [[ -c /dev/tty ]]; then
    read -r -p "${prompt} ${hint} " reply </dev/tty || true
  else
    read -r -p "${prompt} ${hint} " reply || true
  fi
  reply="${reply:-${default}}"
  case "${reply}" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

# Destructive overwrite gate. --yes alone is never enough.
# Returns: 0 allow · 2 soft-decline (--ask said no) · 1 hard refuse.
# -f/--force-overwrite always allows; --ask prompts on a real TTY only.
safety_require_force_overwrite() {
  local what="$1"
  if [[ "${LINUXBKUP_FORCE_OVERWRITE:-0}" -eq 1 ]]; then
    log_warn "force-overwrite enabled for: ${what}"
    return 0
  fi
  if [[ "${LINUXBKUP_ASK:-0}" -eq 1 && -t 0 ]]; then
    if safety_confirm "Overwrite ${what}?" n; then
      log_warn "overwrite approved via --ask for: ${what}"
      return 0
    fi
    log_skip "overwrite declined for: ${what}"
    return 2
  fi
  if [[ "${LINUXBKUP_ASK:-0}" -eq 1 ]]; then
    log_warn "--ask needs a TTY to confirm overwrite — refusing ${what}"
  fi
  log_fatal "Refusing to overwrite ${what}. Pass -f/--force-overwrite, or -a/--ask in a TTY."
  return 1
}

# Secrets under --yes: encryption passphrase must come from env, or
# explicit --no-secrets / --secrets-plain. Never from argv.
safety_secrets_mode_for_yes() {
  if [[ "${LINUXBKUP_NO_SECRETS:-0}" -eq 1 ]]; then
    printf '%s\n' "exclude"
    return 0
  fi
  if [[ "${LINUXBKUP_SECRETS_PLAIN:-0}" -eq 1 ]]; then
    printf '%s\n' "plain"
    return 0
  fi
  if [[ -n "${LINUXBKUP_SECRETS_PASS_FILE:-}" && -r "${LINUXBKUP_SECRETS_PASS_FILE}" ]]; then
    LINUXBKUP_SECRETS_PASS="$(<"${LINUXBKUP_SECRETS_PASS_FILE}")"
    export LINUXBKUP_SECRETS_PASS
  fi
  if [[ -n "${LINUXBKUP_SECRETS_PASS:-}" ]]; then
    printf '%s\n' "encrypt"
    return 0
  fi
  log_fatal "--yes backup with secrets requires LINUXBKUP_SECRETS_PASS(_FILE), --no-secrets, or --secrets-plain"
  return 1
}

# --- Signals -----------------------------------------------------------------

# shellcheck source=lib/core/interrupt.sh
source "${LINUXBKUP_ROOT}/lib/core/interrupt.sh"

_safety_ui_cleanup() {
  if declare -F term_live_park >/dev/null 2>&1; then
    term_live_park
  else
    declare -F term_cursor_show >/dev/null 2>&1 && term_cursor_show
  fi
}

# Ops that apply LINUXBKUP_INTERRUPT_ACTION after the current syscall returns.
_linuxbkup_op_has_waiter() {
  case "${LINUXBKUP_OP_STEP:-}" in
    classify|checksum|pack|copy|snapshot|apt-capture|verify|verify-extract|plan|inspect|index|secrets)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# TERM children (never INT — set -m job teardown can re-raise INT to us).
# Use BASHPID: $$ is the parent even inside $()/subshells — pkill -P $$ would
# kill sibling jobs (and the harness itself during smoke proofs).
_safety_stop_children() {
  local pid self="${BASHPID:-$$}"
  for pid in $(jobs -p 2>/dev/null); do
    kill -TERM "${pid}" 2>/dev/null || true
  done
  if command -v pkill >/dev/null 2>&1; then
    pkill -TERM -P "${self}" 2>/dev/null || true
  else
    for pid in $(ps -o pid= --ppid "${self}" 2>/dev/null); do
      [[ -z "${pid}" || "${pid}" == "${self}" ]] && continue
      kill -TERM "${pid}" 2>/dev/null || true
    done
  fi
  wait 2>/dev/null || true
}

# Ctrl+C — menu (never silent continue). Second Ctrl+C in menu → hard quit.
# INT stays ignored after resume choices until interrupt_resolve/arm — otherwise
# monitor-mode re-raises kill the shell right after "retrying…".
safety_on_int() {
  if [[ "${LINUXBKUP_INT_BUSY:-0}" -eq 1 ]]; then
    _safety_ui_cleanup
    log_fatal "Interrupted (forced)"
    exit 130
  fi
  LINUXBKUP_INT_BUSY=1
  LINUXBKUP_WAS_INTERRUPTED=1
  # Ignore re-raised INT from child/job teardown before any kill/wait.
  trap '' INT
  _safety_ui_cleanup
  _safety_stop_children

  # Real TTYs get the menu; smoke may inject LINUXBKUP_TEST_INTERRUPT_REPLY.
  if [[ -z "${LINUXBKUP_TEST_INTERRUPT_REPLY:-}" && ! -t 0 && ! -c /dev/tty ]]; then
    log_fatal "Interrupted (non-TTY) — exiting"
    exit 130
  fi

  trap 'log_fatal "Interrupted (forced)"; exit 130' INT
  linuxbkup_interrupt_menu

  case "${LINUXBKUP_INTERRUPT_ACTION}" in
    quit|quit_clean)
      LINUXBKUP_INT_BUSY=0
      linuxbkup_interrupt_apply >/dev/null
      ;;
    *)
      LINUXBKUP_INT_BUSY=0
      # Keep INT ignored for waiters until resolve; idle re-arms below.
      trap '' INT
      if [[ -n "${TERM_PROGRESS_T0+x}" ]]; then
        TERM_PROGRESS_T0="$(date +%s)"
      fi
      if [[ "${LINUXBKUP_OP_CAN_SKIP:-0}" -eq 1 && -n "${LINUXBKUP_OP_ITEM:-}" ]]; then
        log_info "Paused — will ${LINUXBKUP_INTERRUPT_ACTION} when the current copy returns"
      elif _linuxbkup_op_has_waiter; then
        if [[ "${LINUXBKUP_INTERRUPT_ACTION}" == "retry" || "${LINUXBKUP_OP_REDO:-0}" -eq 1 ]]; then
          log_info "Paused — will retry ${LINUXBKUP_OP_STEP} (discard partial)"
        else
          log_info "Paused — will ${LINUXBKUP_INTERRUPT_ACTION} ${LINUXBKUP_OP_STEP}"
        fi
      else
        log_info "Continuing…"
        LINUXBKUP_INTERRUPT_ACTION=""
        LINUXBKUP_WAS_INTERRUPTED=0
        LINUXBKUP_OP_REDO=0
        linuxbkup_interrupt_arm
      fi
      if [[ "${TERM_PROGRESS_ACTIVE:-0}" -eq 1 ]]; then
        declare -F term_progress_resume_paint >/dev/null 2>&1 && term_progress_resume_paint
      fi
      ;;
  esac
}

safety_on_term() {
  _safety_ui_cleanup
  declare -F term_progress_end >/dev/null 2>&1 && term_progress_end
  declare -F linuxbkup_tty_restore >/dev/null 2>&1 && linuxbkup_tty_restore
  log_fatal "Terminated (SIGTERM)"
  exit 143
}

# Prefer /dev/tty — live progress often owns stderr.
_safety_tty_msg() {
  if [[ -c /dev/tty ]]; then
    printf '%s\n' "$*" >/dev/tty 2>/dev/null || printf '%s\n' "$*" >&2
  else
    printf '%s\n' "$*" >&2
  fi
}

LINUXBKUP_WAS_SUSPENDED=0

# Ctrl+Z — park UI, STOP process group (bash + children). Needs set -m;
# otherwise only the child stops and bash wedges in wait. Not a kill path.
safety_on_tstp() {
  LINUXBKUP_WAS_SUSPENDED=1
  printf '\033[?25h' >/dev/tty 2>/dev/null || true
  _safety_ui_cleanup
  declare -F term_cursor_show >/dev/null 2>&1 && term_cursor_show
  _safety_tty_msg ""
  _safety_tty_msg "[INFO] Suspended (Ctrl+Z) — back at your shell"
  _safety_tty_msg "[INFO] Resume: fg     |  background: bg"
  if [[ -n "${LINUXBKUP_OP_STEP:-}" ]]; then
    _safety_tty_msg "[INFO] Step: ${LINUXBKUP_OP_STEP}${LINUXBKUP_OP_ITEM:+ — ${LINUXBKUP_OP_ITEM}}"
  fi

  trap - TSTP
  kill -STOP 0 2>/dev/null || kill -STOP -$$ 2>/dev/null || kill -STOP "$$" 2>/dev/null || true
  trap 'safety_on_tstp' TSTP
}

# After fg/bg+CONT: reset ETA and redraw progress.
safety_on_cont() {
  [[ "${LINUXBKUP_WAS_SUSPENDED:-0}" -eq 1 ]] || return 0
  LINUXBKUP_WAS_SUSPENDED=0
  if [[ -n "${TERM_PROGRESS_T0+x}" ]]; then
    TERM_PROGRESS_T0="$(date +%s)"
  fi
  _safety_tty_msg "[INFO] Resumed — ETA clock reset"
  if [[ "${TERM_PROGRESS_ACTIVE:-0}" -eq 1 ]]; then
    declare -F term_progress_resume_paint >/dev/null 2>&1 && term_progress_resume_paint
  fi
}

linuxbkup_install_traps() {
  # Monitor mode so tty ^Z suspends the whole job group (not only the child).
  set -m 2>/dev/null || true
  trap 'safety_on_int' INT
  trap 'safety_on_term' TERM
  trap 'safety_on_tstp' TSTP
  trap 'safety_on_cont' CONT
  trap 'linuxbkup_tty_restore' EXIT
}

# Permission / unreadable path policy. Never auto-sudo.
# Prints: continue | abort
safety_permission_policy() {
  local path="$1"
  local detail="${2:-permission denied}"

  LINUXBKUP_PERM_SKIPS=$((LINUXBKUP_PERM_SKIPS + 1))
  log_warn "${detail} — soft-skip: ${path}"
  log_verbose "permission policy: never auto-sudo; unreadable files skipped"
  log_debug "perm_skips=${LINUXBKUP_PERM_SKIPS} path=${path} detail=${detail}"

  if [[ "${LINUXBKUP_YES:-0}" -eq 1 || "${LINUXBKUP_PERM_SKIP_ALL:-0}" -eq 1 || ! -t 0 ]]; then
    printf '%s\n' "continue"
    return 0
  fi

  if safety_confirm "Skip unreadable paths and continue? (further denials auto-skip)" "y"; then
    LINUXBKUP_PERM_SKIP_ALL=1
    export LINUXBKUP_PERM_SKIP_ALL
    printf '%s\n' "continue"
    return 0
  fi
  printf '%s\n' "abort"
  return 0
}

# Run rsync; treat partial transfer (23/24) as soft-skip, not fatal.
# Returns: 0 ok, 1 hard fail, 20 interrupted (SIGINT / user menu pending).
backup_rsync_run() {
  local -a args=("$@")
  local rc=0 err
  err="$(mktemp "${TMPDIR:-/tmp}/linuxbkup-rsync.XXXXXX")"

  # Re-arm after interrupt_resolve left INT ignored through retry setup.
  linuxbkup_interrupt_arm
  log_debug "rsync: ${args[*]}"
  # Drop monitor mode so tty ^C hits our trap (not only rsync's PGID).
  set +e
  linuxbkup_without_monitor rsync "${args[@]}" 2>"${err}"
  rc=$?
  set -e

  if [[ "${rc}" -eq 0 ]]; then
    rm -f "${err}"
    return 0
  fi

  # 20 = SIGINT — never soft-skip
  if [[ "${rc}" -eq 20 || "${LINUXBKUP_WAS_INTERRUPTED:-0}" -eq 1 ]]; then
    rm -f "${err}"
    LINUXBKUP_WAS_INTERRUPTED=1
    return 20
  fi

  local label="${args[$((${#args[@]} - 1))]:-rsync}"

  if [[ "${rc}" -eq 23 || "${rc}" -eq 24 ]]; then
    local sample
    sample="$(grep -i 'permission denied\|failed to open\|vanished' "${err}" 2>/dev/null | head -n 3 || true)"
    [[ -n "${sample}" ]] && log_verbose "rsync notes: ${sample}"
    log_debug "rsync rc=${rc} stderr=$(tr '\n' ' ' <"${err}" | head -c 400)"
    rm -f "${err}"
    local decision
    decision="$(safety_permission_policy "${label}" "rsync partial (rc=${rc})")"
    [[ "${decision}" == "abort" ]] && return 1
    return 0
  fi

  log_warn "rsync failed (rc=${rc})"
  [[ -s "${err}" ]] && log_verbose "$(head -n 5 "${err}")"
  log_debug "rsync stderr: $(tr '\n' ' ' <"${err}" | head -c 400)"
  rm -f "${err}"
  local decision
  decision="$(safety_permission_policy "${label}" "rsync failed rc=${rc}")"
  [[ "${decision}" == "abort" ]] && return 1
  return 0
}

# After rsync: 0 + LINUXBKUP_INTERRUPT_RESULT if interrupt; 1 if not.
backup_handle_interrupt() {
  local rc="${1:-0}"
  if [[ "${rc}" -eq 20 || "${LINUXBKUP_WAS_INTERRUPTED:-0}" -eq 1 || -n "${LINUXBKUP_INTERRUPT_ACTION:-}" ]]; then
    LINUXBKUP_WAS_INTERRUPTED=1
    linuxbkup_interrupt_resolve
    return 0
  fi
  return 1
}
