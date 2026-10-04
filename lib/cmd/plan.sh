# shellcheck shell=bash

linuxbkup_cmd_plan() {
  if cmd_want_help "$@"; then
    linuxbkup_cmd_help plan
    return 0
  fi

  # shellcheck source=lib/core/context.sh
  source "${LINUXBKUP_ROOT}/lib/core/context.sh"
  # shellcheck source=lib/constraints/base.sh
  source "${LINUXBKUP_ROOT}/lib/constraints/base.sh"
  # shellcheck source=lib/env/users.sh
  source "${LINUXBKUP_ROOT}/lib/env/users.sh"
  # shellcheck source=lib/fs/sizes.sh
  source "${LINUXBKUP_ROOT}/lib/fs/sizes.sh"
  # shellcheck source=lib/classify/plan.sh
  source "${LINUXBKUP_ROOT}/lib/classify/plan.sh"

  local user home
  user="$(env_resolve_user)"
  if ! home="$(env_user_home "${user}")"; then
    log_fatal "No home directory for user: ${user}"
    return 1
  fi

  # JSON mode: minimal banner noise — tools check still useful for du when -v
  if [[ "${LINUXBKUP_JSON:-0}" -eq 1 ]]; then
    log_debug "plan --json home=${home}"
    if [[ "${LINUXBKUP_VERBOSE:-0}" -ne 1 && "${LINUXBKUP_DEBUG:-0}" -ne 1 ]]; then
      LINUXBKUP_INSPECT_QUICK=1
    fi
    classify_print_plan_json "${home}"
    return 0
  fi

  cmd_context_begin plan \
    --desc "Show what backup would include/skip (no files written)." \
    --required find \
    --optional du timeout numfmt

  log_verbose "plan start home=${home}"
  if [[ "${LINUXBKUP_VERBOSE:-0}" -ne 1 && "${LINUXBKUP_DEBUG:-0}" -ne 1 ]]; then
    LINUXBKUP_INSPECT_QUICK=1
  fi

  classify_print_plan "${home}"
  printf '\n'
  log_ok "plan complete"
  # Prefer -y in tip when unexpected would ask (so tip matches “execute with these defaults”)
  if [[ "${LINUXBKUP_YES:-0}" -ne 1 ]] && [[ -t 0 ]]; then
    ui_item note "Tip: add -y to auto-include unexpected paths"
  fi
  linuxbkup_tip_run backup
}
