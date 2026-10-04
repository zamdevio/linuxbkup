# shellcheck shell=bash
# Confirmation and destructive-action gates.

# Confirm a question. Returns 0 if approved.
# With WSLBKUP_YES=1, accepts the provided default (safe path only).
# Usage: safety_confirm "Proceed with backup?" y
safety_confirm() {
  local prompt="$1"
  local default="${2:-n}" # y|n
  local reply

  if [[ "${WSLBKUP_YES:-0}" -eq 1 ]]; then
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

  read -r -p "${prompt} ${hint} " reply || true
  reply="${reply:-${default}}"
  case "${reply}" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

# Destructive overwrite gate. --yes alone is never enough.
safety_require_force_overwrite() {
  local what="$1"
  if [[ "${WSLBKUP_FORCE_OVERWRITE:-0}" -eq 1 ]]; then
    log_warn "force-overwrite enabled for: ${what}"
    return 0
  fi
  log_fatal "Refusing to overwrite ${what}. Pass --force-overwrite if intentional."
  return 1
}

# Secrets under --yes: encryption passphrase must come from env, or
# explicit --no-secrets / --secrets-plain. Never from argv.
safety_secrets_mode_for_yes() {
  if [[ "${WSLBKUP_NO_SECRETS:-0}" -eq 1 ]]; then
    printf '%s\n' "exclude"
    return 0
  fi
  if [[ "${WSLBKUP_SECRETS_PLAIN:-0}" -eq 1 ]]; then
    printf '%s\n' "plain"
    return 0
  fi
  if [[ -n "${WSLBKUP_SECRETS_PASS:-}" ]]; then
    printf '%s\n' "encrypt"
    return 0
  fi
  log_fatal "--yes backup with secrets requires WSLBKUP_SECRETS_PASS, --no-secrets, or --secrets-plain"
  return 1
}

wslbkup_install_traps() {
  trap 'log_fatal "Aborted (signal)"; exit 130' INT TERM
}
