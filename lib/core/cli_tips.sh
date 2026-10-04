# shellcheck shell=bash
# Rebuild CLI flag strings for plan↔backup tips (same effective options).

# Append shell-quoted tokens to named array. Args: array_name tokens...
_tips_push() {
  local __name="$1"
  shift
  local t __q
  for t in "$@"; do
    printf -v __q '%q' "${t}"
    eval "${__name}+=(\"\${__q}\")"
  done
}

# Flags that affect classification / plan (shared by plan + backup).
# Args: name of array to fill
linuxbkup_flags_plan_relevant() {
  local __name="$1"
  eval "${__name}=()"
  local inc ex

  if [[ "${LINUXBKUP_ASK:-0}" -eq 1 ]]; then _tips_push "${__name}" --ask; fi
  if [[ "${LINUXBKUP_YES:-0}" -eq 1 ]]; then _tips_push "${__name}" -y; fi
  if [[ -n "${LINUXBKUP_PROFILE:-}" && "${LINUXBKUP_PROFILE}" != "balanced" ]]; then
    _tips_push "${__name}" --profile "${LINUXBKUP_PROFILE}"
  fi
  if [[ "${LINUXBKUP_VERBOSE:-0}" -eq 1 && "${LINUXBKUP_DEBUG:-0}" -ne 1 ]]; then
    _tips_push "${__name}" -v
  fi
  if [[ "${LINUXBKUP_DEBUG:-0}" -eq 1 ]]; then _tips_push "${__name}" -d; fi
  if [[ "${LINUXBKUP_NO_COLOR:-0}" -eq 1 ]]; then _tips_push "${__name}" --no-color; fi
  if [[ "${LINUXBKUP_NO_LINKS:-0}" -eq 1 ]]; then _tips_push "${__name}" --no-links; fi
  if [[ "${LINUXBKUP_NO_DEFAULTS:-0}" -eq 1 ]]; then _tips_push "${__name}" --no-defaults; fi
  if [[ "${LINUXBKUP_NO_SECRETS:-0}" -eq 1 ]]; then _tips_push "${__name}" --no-secrets; fi
  if [[ "${LINUXBKUP_SECRETS_PLAIN:-0}" -eq 1 ]]; then _tips_push "${__name}" --secrets-plain; fi
  if [[ "${LINUXBKUP_LIST_FULL:-0}" -eq 1 ]]; then _tips_push "${__name}" -F; fi
  if [[ -n "${LINUXBKUP_LIST_TOP:-}" && "${LINUXBKUP_LIST_FULL:-0}" -ne 1 ]]; then
    _tips_push "${__name}" -T "${LINUXBKUP_LIST_TOP}"
  fi
  if [[ -n "${LINUXBKUP_USER:-}" ]]; then
    _tips_push "${__name}" --user "${LINUXBKUP_USER}"
  fi
  for inc in "${LINUXBKUP_INCLUDE_REGEXES[@]+"${LINUXBKUP_INCLUDE_REGEXES[@]}"}"; do
    _tips_push "${__name}" --include "${inc}"
  done
  for ex in "${LINUXBKUP_EXCLUDE_REGEXES[@]+"${LINUXBKUP_EXCLUDE_REGEXES[@]}"}"; do
    _tips_push "${__name}" --exclude "${ex}"
  done
  return 0
}

# Flags for tipping to backup (plan-relevant + output/dry-run when set).
linuxbkup_flags_backup_relevant() {
  local __name="$1"
  linuxbkup_flags_plan_relevant "${__name}"
  if [[ -n "${LINUXBKUP_OUTPUT:-}" ]]; then
    _tips_push "${__name}" -o "${LINUXBKUP_OUTPUT}"
  fi
  if [[ -n "${LINUXBKUP_MAX_SIZE_BYTES:-}" && "${LINUXBKUP_MAX_SIZE_BYTES}" -gt 0 ]]; then
    _tips_push "${__name}" --max-size "${LINUXBKUP_MAX_SIZE_BYTES}"
  fi
  if [[ "${LINUXBKUP_KEEP_STAGE:-0}" -eq 1 ]]; then
    _tips_push "${__name}" --keep-stage
  fi
  if [[ -n "${LINUXBKUP_STAGE_DIR:-}" ]]; then
    _tips_push "${__name}" --stage-dir "${LINUXBKUP_STAGE_DIR}"
  fi
  if [[ "${LINUXBKUP_DRY_RUN:-0}" -eq 1 ]]; then
    _tips_push "${__name}" --dry-run
  fi
  return 0
}

# Print a tip line. Args: verb (plan|backup)
linuxbkup_tip_run() {
  local target="$1"
  local -a flags=()
  local line

  case "${target}" in
    plan) linuxbkup_flags_plan_relevant flags ;;
    backup) linuxbkup_flags_backup_relevant flags ;;
    *)
      log_debug "tip: unknown target ${target}"
      return 0
      ;;
  esac

  if [[ "${#flags[@]}" -gt 0 ]]; then
    line="linuxbkup ${flags[*]} ${target}"
  else
    line="linuxbkup ${target}"
  fi
  ui_item note "Run: ${line}"
  return 0
}
