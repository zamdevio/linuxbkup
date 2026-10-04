# shellcheck shell=bash
# Backup profiles: size thresholds + suggestion defaults for --ask / --yes.

# Default profile (portable + reasonably safe).
LINUXBKUP_PROFILE="${LINUXBKUP_PROFILE:-balanced}"

# Apply after flag parse: --ask wins over --yes (logged once).
linuxbkup_apply_ask_yes_precedence() {
  if [[ "${LINUXBKUP_ASK:-0}" -eq 1 && "${LINUXBKUP_YES:-0}" -eq 1 ]]; then
    log_info "ignoring --yes because --ask is set"
    LINUXBKUP_YES=0
  fi
  # non-TTY without --ask/--yes → script-safe defaults (= --yes)
  if [[ "${LINUXBKUP_ASK:-0}" -ne 1 && "${LINUXBKUP_YES:-0}" -ne 1 && ! -t 0 ]]; then
    log_info "non-TTY stdin — using --yes defaults for include/skip decisions"
    LINUXBKUP_YES=1
  fi
}

linuxbkup_profile_validate() {
  case "${LINUXBKUP_PROFILE}" in
    easy|balanced|strict) return 0 ;;
    *)
      log_fatal "unknown --profile '${LINUXBKUP_PROFILE}' (easy|balanced|strict)"
      return 1
      ;;
  esac
}

# Large directory threshold in bytes for active profile.
profile_large_dir_bytes() {
  case "${LINUXBKUP_PROFILE:-balanced}" in
    easy) printf '%s\n' "$((2 * 1024 * 1024 * 1024))" ;;
    strict) printf '%s\n' "$((100 * 1024 * 1024))" ;;
    *) printf '%s\n' "$((500 * 1024 * 1024))" ;; # balanced
  esac
}

# Large file threshold in bytes for active profile.
profile_large_file_bytes() {
  case "${LINUXBKUP_PROFILE:-balanced}" in
    easy) printf '%s\n' "$((500 * 1024 * 1024))" ;;
    strict) printf '%s\n' "$((50 * 1024 * 1024))" ;;
    *) printf '%s\n' "$((100 * 1024 * 1024))" ;; # balanced
  esac
}

# Suggested action for large items under --ask: include|skip
profile_suggest_large() {
  case "${LINUXBKUP_PROFILE:-balanced}" in
    strict) printf '%s\n' "skip" ;;
    *) printf '%s\n' "include" ;;
  esac
}

# Under --yes (no --ask): should large paths be kept? 0=skip 1=include
profile_yes_include_large() {
  case "${LINUXBKUP_PROFILE:-balanced}" in
    strict) return 1 ;;
    *) return 0 ;;
  esac
}

# True if path+bytes is "large" for the active profile.
profile_is_large() {
  local path="$1" bytes="${2:-0}"
  local thr
  [[ "${bytes}" =~ ^[0-9]+$ ]] || bytes=0
  [[ "${bytes}" -gt 0 ]] || return 1
  if [[ -d "${path}" ]]; then
    thr="$(profile_large_dir_bytes)"
  else
    thr="$(profile_large_file_bytes)"
  fi
  [[ "${bytes}" -ge "${thr}" ]]
}
