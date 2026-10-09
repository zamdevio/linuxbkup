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
# Args: [wait_ds] centiseconds to wait after TERM before KILL (default 30 = 3s)
_safety_stop_children() {
  local pid self="${BASHPID:-$$}" waited=0 max_ds="${1:-30}"
  local -a pids=() alive=()

  for pid in $(jobs -p 2>/dev/null); do
    [[ -n "${pid}" ]] && pids+=("${pid}")
  done
  if command -v pgrep >/dev/null 2>&1; then
    for pid in $(pgrep -P "${self}" 2>/dev/null); do
      [[ -n "${pid}" ]] && pids+=("${pid}")
    done
  else
    for pid in $(ps -o pid= --ppid "${self}" 2>/dev/null); do
      [[ -n "${pid}" && "${pid}" != "${self}" ]] && pids+=("${pid}")
    done
  fi
  # Reinstall PM children often live under bash -c; match active project dir
  if [[ -n "${REINSTALL_ACTIVE_DIR:-}" ]] && command -v pgrep >/dev/null 2>&1; then
    for pid in $(pgrep -f "${REINSTALL_ACTIVE_DIR}" 2>/dev/null); do
      [[ -n "${pid}" && "${pid}" != "${self}" ]] && pids+=("${pid}")
    done
  fi
  if [[ "${#pids[@]}" -eq 0 ]]; then
    wait 2>/dev/null || true
    return 0
  fi

  for pid in "${pids[@]}"; do
    kill -TERM "${pid}" 2>/dev/null || true
  done
  # Graceful window — npm/pnpm need a moment to unwind
  while [[ "${waited}" -lt "${max_ds}" ]]; do
    alive=()
    for pid in "${pids[@]}"; do
      kill -0 "${pid}" 2>/dev/null && alive+=("${pid}")
    done
    [[ "${#alive[@]}" -eq 0 ]] && break
    sleep 0.1
    waited=$((waited + 1))
  done
  for pid in "${pids[@]}"; do
    if kill -0 "${pid}" 2>/dev/null; then
      kill -KILL "${pid}" 2>/dev/null || true
    fi
  done
  wait 2>/dev/null || true
}

# Immediate ^C paint — before any wait. Shows what is being stopped.
_safety_interrupt_notice() {
  local pm="${REINSTALL_ACTIVE_PM:-}"
  local rel="${REINSTALL_ACTIVE_REL:-}"
  local dir="${REINSTALL_ACTIVE_DIR:-}"
  local cmd="${REINSTALL_ACTIVE_CMD:-}"
  local step="${LINUXBKUP_OP_STEP:-}"
  local item="${LINUXBKUP_OP_ITEM:-}"
  local pids="" pid

  pids="$(_safety_child_pids | tr '\n' ' ')"
  pids="$(printf '%s' "${pids}" | sed 's/[[:space:]]*$//')"

  _safety_tty_msg ""
  _safety_tty_msg "[INT] Ctrl+C — stopping current step…"
  if [[ -n "${pm}" ]]; then
    _safety_tty_msg "[INT] PM:      ${pm}"
    _safety_tty_msg "[INT] Project: ${rel:-${item:-?}}"
    [[ -n "${cmd}" ]] && _safety_tty_msg "[INT] Command: ${cmd}"
  fi
  [[ -n "${step}" ]] && _safety_tty_msg "[INT] Step:    ${step}"
  if [[ -n "${item}" && -z "${rel}" ]]; then
    _safety_tty_msg "[INT] Item:    ${item}"
  fi
  if [[ -n "${pids}" ]]; then
    _safety_tty_msg "[INT] PID(s):  ${pids}"
    # One-line process table when possible (pid, comm, short args)
    if command -v ps >/dev/null 2>&1; then
      # shellcheck disable=SC2086
      ps -o pid=,comm=,args= -p ${pids} 2>/dev/null \
        | head -n 6 \
        | while IFS= read -r line; do
          _safety_tty_msg "[INT]   ${line}"
        done || true
    fi
  else
    _safety_tty_msg "[INT] PID(s):  (none found yet)"
  fi
  _safety_tty_msg "[INT] Waiting for ${pm:-child process} to exit (TERM → ${LINUXBKUP_INT_STOP_WAIT:-3}s → KILL)…"
  _safety_tty_msg "[INT] Menu appears when it is gone — please wait."
}

# Live child PIDs (jobs + pgrep + active reinstall dir match). One per line.
_safety_child_pids() {
  local self="${BASHPID:-$$}" pid
  local -A seen=()
  for pid in $(jobs -p 2>/dev/null); do
    [[ -n "${pid}" && -z "${seen[${pid}]+x}" ]] || continue
    seen["${pid}"]=1
    printf '%s\n' "${pid}"
  done
  if command -v pgrep >/dev/null 2>&1; then
    for pid in $(pgrep -P "${self}" 2>/dev/null); do
      [[ -n "${pid}" && -z "${seen[${pid}]+x}" ]] || continue
      seen["${pid}"]=1
      printf '%s\n' "${pid}"
    done
  else
    for pid in $(ps -o pid= --ppid "${self}" 2>/dev/null); do
      [[ -n "${pid}" && "${pid}" != "${self}" && -z "${seen[${pid}]+x}" ]] || continue
      seen["${pid}"]=1
      printf '%s\n' "${pid}"
    done
  fi
  if [[ -n "${REINSTALL_ACTIVE_DIR:-}" ]] && command -v pgrep >/dev/null 2>&1; then
    for pid in $(pgrep -f "${REINSTALL_ACTIVE_DIR}" 2>/dev/null); do
      [[ -n "${pid}" && "${pid}" != "${self}" && -z "${seen[${pid}]+x}" ]] || continue
      seen["${pid}"]=1
      printf '%s\n' "${pid}"
    done
  fi
  return 0
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
  # Paint immediately so the user sees what is stopping (PM/pid/project)
  _safety_interrupt_notice
  _safety_stop_children "${LINUXBKUP_INT_STOP_WAIT_DS:-30}"

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
# Open failure (no controlling tty) must stay silent — fall back to stderr.
_safety_tty_msg() {
  if { [[ -c /dev/tty ]] && printf '%s\n' "$*" >/dev/tty; } 2>/dev/null; then
    return 0
  fi
  printf '%s\n' "$*" >&2
}

LINUXBKUP_WAS_SUSPENDED=0

# Ctrl+Z — park UI, STOP process group (bash + children). Needs set -m;
# otherwise only the child stops and bash wedges in wait. Not a kill path.
# Phase 13 B: cover restore extract/rsync/reinstall (not only backup pack).
# BusyBox hosts may lack reliable job control — fall back to stopping self
# after children so fg/bg still resume.
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
  if [[ -n "${REINSTALL_ACTIVE_PM:-}" ]]; then
    _safety_tty_msg "[INFO] PM: ${REINSTALL_ACTIVE_PM}${REINSTALL_ACTIVE_DIR:+ — ${REINSTALL_ACTIVE_DIR}}"
  fi

  trap - TSTP
  # Monitor mode so tty ^Z suspends the whole job group (restore extract,
  # rsync, reinstall all run under without_monitor → set +m; re-assert here).
  set -m 2>/dev/null || true
  # STOP children first (explicit PIDs), then the process group, then self.
  # kill -STOP 0 alone can miss children when monitor mode was off mid-op.
  local _pid
  for _pid in $(_safety_child_pids 2>/dev/null); do
    [[ -n "${_pid}" ]] && kill -STOP "${_pid}" 2>/dev/null || true
  done
  kill -STOP 0 2>/dev/null || kill -STOP -$$ 2>/dev/null || true
  kill -STOP "$$" 2>/dev/null || true
  trap 'safety_on_tstp' TSTP
}

# After fg/bg+CONT: reset ETA, re-assert monitor mode, redraw progress.
safety_on_cont() {
  [[ "${LINUXBKUP_WAS_SUSPENDED:-0}" -eq 1 ]] || return 0
  LINUXBKUP_WAS_SUSPENDED=0
  # Restore may have been mid without_monitor (set +m) — re-enable job control
  # so the next Ctrl+Z suspends the whole group again.
  set -m 2>/dev/null || true
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
# Side effect: sets LINUXBKUP_PERM_DEST_FAIL=1 (and LINUXBKUP_PERM_DEST_ERR)
# when stderr shows a destination-side failure, so restore can hard-fail
# instead of soft-skipping (BUG 3).
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

  # Destination-side failure detection (BUG 3): read-only / unwritable target
  # must never be reported as a soft "unreadable source" skip.
  # Sets LINUXBKUP_PERM_DEST_FAIL=1 for the caller; global default 0.
  LINUXBKUP_PERM_DEST_FAIL=0
  if grep -qiE 'read-only file system|no space left|destination.*(denied|not writable)|mkstemp.*failed|failed to open.*dest' "${err}" 2>/dev/null; then
    LINUXBKUP_PERM_DEST_FAIL=1
    LINUXBKUP_PERM_DEST_ERR="${err}"
    log_debug "rsync rc=${rc} dest-side failure: $(tr '\n' ' ' <"${err}" | head -c 300)"
    return "${rc}"
  fi

  if [[ "${rc}" -eq 23 || "${rc}" -eq 24 ]]; then
    local sample
    sample="$(grep -i 'permission denied\|failed to open\|vanished' "${err}" 2>/dev/null | head -n 3 || true)"
    [[ -n "${sample}" ]] && log_verbose "rsync notes: ${sample}"
    log_debug "rsync rc=${rc} stderr=$(tr '\n' ' ' <"${err}" | head -c 400)"
    rm -f "${err}"
    # Strict (restore): partial rsync is never recoverable — hard-fail.
    if [[ "${LINUXBKUP_RSYNC_STRICT:-0}" -eq 1 ]]; then
      log_warn "rsync partial copy (rc=${rc}) — failing (strict)"
      return 1
    fi
    local decision
    decision="$(safety_permission_policy "${label}" "rsync partial (rc=${rc})")"
    [[ "${decision}" == "abort" ]] && return 1
    return 0
  fi

  log_warn "rsync failed (rc=${rc})"
  [[ -s "${err}" ]] && log_verbose "$(head -n 5 "${err}")"
  log_debug "rsync stderr: $(tr '\n' ' ' <"${err}" | head -c 400)"
  rm -f "${err}"
  # Strict (restore): any non-interrupt failure is a hard failure — never soft-skip.
  if [[ "${LINUXBKUP_RSYNC_STRICT:-0}" -eq 1 ]]; then
    return 1
  fi
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
