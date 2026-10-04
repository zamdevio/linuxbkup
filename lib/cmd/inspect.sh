# shellcheck shell=bash

wslbkup_cmd_inspect() {
  if cmd_want_help "$@"; then
    wslbkup_cmd_help inspect
    return 0
  fi

  # shellcheck source=lib/core/context.sh
  source "${WSLBKUP_ROOT}/lib/core/context.sh"
  # shellcheck source=lib/constraints/base.sh
  source "${WSLBKUP_ROOT}/lib/constraints/base.sh"
  # shellcheck source=lib/env/distro.sh
  source "${WSLBKUP_ROOT}/lib/env/distro.sh"
  # shellcheck source=lib/env/users.sh
  source "${WSLBKUP_ROOT}/lib/env/users.sh"
  # shellcheck source=lib/env/capabilities.sh
  source "${WSLBKUP_ROOT}/lib/env/capabilities.sh"
  # shellcheck source=lib/windows/paths.sh
  source "${WSLBKUP_ROOT}/lib/windows/paths.sh"
  # shellcheck source=lib/fs/sizes.sh
  source "${WSLBKUP_ROOT}/lib/fs/sizes.sh"
  # shellcheck source=lib/classify/paths.sh
  source "${WSLBKUP_ROOT}/lib/classify/paths.sh"

  cmd_context_begin inspect \
    --desc "Read-only environment scan — no files are modified." \
    --required du find \
    --optional timeout numfmt age tar zstd rsync sha256sum

  local user home
  user="$(env_resolve_user)"
  if ! home="$(env_user_home "${user}")"; then
    home="(unavailable)"
  fi

  ui_heading "Environment inspection"

  env_print_distribution
  printf '\n'
  env_print_users
  printf '\n'
  env_print_package_managers
  printf '\n'
  env_print_services
  printf '\n'
  env_print_dev_environments
  printf '\n'
  env_print_backup_tools
  printf '\n'

  if [[ "${home}" != "(unavailable)" ]]; then
    fs_print_filesystem "${home}"
    printf '\n'
    classify_print_summary "${home}"
    printf '\n'
  else
    log_warn "Skipping filesystem scan — home unavailable for ${user}"
    printf '\n'
  fi

  windows_print_backup_destination
  printf '\n'
  log_ok "inspect complete"
}
