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
safety_require_force_overwrite() {
  local what="$1"
  if [[ "${LINUXBKUP_FORCE_OVERWRITE:-0}" -eq 1 ]]; then
    log_warn "force-overwrite enabled for: ${what}"
    return 0
  fi
  log_fatal "Refusing to overwrite ${what}. Pass --force-overwrite if intentional."
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

LINUXBKUP_INT_BUSY=0

# Restore terminal after interrupt/suspend mid-progress.
_safety_ui_cleanup() {
  declare -F term_progress_end >/dev/null 2>&1 && term_progress_end
  declare -F term_cursor_show >/dev/null 2>&1 && term_cursor_show
}

# Ctrl+C — confirm on TTY to avoid accidental abort; non-TTY exits immediately.
safety_on_int() {
  if [[ "${LINUXBKUP_INT_BUSY:-0}" -eq 1 ]]; then
    _safety_ui_cleanup
    log_fatal "Interrupted"
    exit 130
  fi
  LINUXBKUP_INT_BUSY=1
  printf '\n' >&2
  _safety_ui_cleanup

  if [[ ! -t 0 && ! -c /dev/tty ]]; then
    log_fatal "Interrupted (non-TTY)"
    exit 130
  fi

  # Nested INT during confirm → exit
  trap 'log_fatal "Interrupted"; exit 130' INT
  if safety_confirm "Stop linuxbkup and exit?" "n"; then
    log_fatal "Interrupted by user"
    exit 130
  fi
  trap 'safety_on_int' INT
  LINUXBKUP_INT_BUSY=0
  log_info "Continuing…"
}

# SIGTERM — no confirm (external kill)
safety_on_term() {
  _safety_ui_cleanup
  log_fatal "Terminated (SIGTERM)"
  exit 143
}

# Ctrl+Z — allow suspend; guide resume with fg (TTY-aware).
# After fg, reinstall trap and continue.
safety_on_tstp() {
  printf '\n' >&2
  _safety_ui_cleanup
  if [[ -t 0 || -t 1 || -c /dev/tty ]]; then
    log_info "Stopped (Ctrl+Z) — job suspended in this shell"
    log_info "Resume with: fg"
    log_info "If a prompt/password was pending, use fg (not bg) so the TTY can attach again"
  else
    log_info "Stopped (SIGTSTP)"
  fi
  # Deliver real stop; when fg resumes, execution continues below
  trap - TSTP
  kill -s TSTP "$$" 2>/dev/null || kill -STOP "$$"
  trap 'safety_on_tstp' TSTP
  log_info "Resumed (fg)"
}

# Install process-wide handlers. Safe to call once from the entry binary.
linuxbkup_install_traps() {
  trap 'safety_on_int' INT
  trap 'safety_on_term' TERM
  trap 'safety_on_tstp' TSTP
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
backup_rsync_run() {
  local -a args=("$@")
  local rc=0 err
  err="$(mktemp "${TMPDIR:-/tmp}/linuxbkup-rsync.XXXXXX")"

  log_debug "rsync: ${args[*]}"
  set +e
  rsync "${args[@]}" 2>"${err}"
  rc=$?
  set -e

  if [[ "${rc}" -eq 0 ]]; then
    rm -f "${err}"
    return 0
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
