# shellcheck shell=bash
# Confirmation and destructive-action gates.

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
  if [[ -n "${LINUXBKUP_SECRETS_PASS:-}" ]]; then
    printf '%s\n' "encrypt"
    return 0
  fi
  log_fatal "--yes backup with secrets requires LINUXBKUP_SECRETS_PASS, --no-secrets, or --secrets-plain"
  return 1
}

linuxbkup_install_traps() {
  trap 'log_fatal "Aborted (signal)"; exit 130' INT TERM
}

# Permission / unreadable path policy. Never auto-sudo.
# Prints: continue | abort
# --yes / non-TTY / prior skip-all → continue (soft-skip).
# TTY → ask once; accepting enables skip-all for the rest of the run.
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
# Args: same as rsync after the binary name…  OR: backup_rsync <src> <dest> with excludes from BACKUP_RSYNC_EXCLUDES
# Usage: backup_rsync_run -- <rsync args...>
# Returns 0 on ok/partial+continue, 1 on abort/hard fail.
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

  # 23 = partial due to errors (often EACCES); 24 = vanished source files
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
