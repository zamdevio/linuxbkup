# shellcheck shell=bash
# Shared environment snapshot: probe once → print (inspect-class) + notes for backup.

# shellcheck source=lib/env/capabilities.sh
source "${LINUXBKUP_ROOT}/lib/env/capabilities.sh"
# shellcheck source=lib/env/distro.sh
source "${LINUXBKUP_ROOT}/lib/env/distro.sh"

# Print capability sections (same probes as inspect). Args: [mode=backup|inspect]
# backup mode adds a short note about capture coverage after package managers.
env_print_snapshot() {
  local mode="${1:-inspect}"

  ui_section "Environment snapshot"
  ui_item note "Shared probes — detect once, then prepare what this build can stage"

  env_print_distribution
  printf '\n'
  env_print_package_managers
  if [[ "${mode}" == "backup" ]]; then
    if linuxbkup_require_cmd apt-mark && linuxbkup_require_cmd dpkg; then
      ui_item note "capture ready: apt/dpkg manifests"
    else
      ui_item note "capture: apt/dpkg not available on this host"
    fi
    ui_item note "other PMs detected above — manifest modules land after 08.8 (honest gap)"
  fi
  printf '\n'
  env_print_language_tooling
  printf '\n'
  env_print_tool_managers
  printf '\n'
  env_print_services
  printf '\n'
  env_print_web_servers
  printf '\n'
  env_print_databases
  printf '\n'
  env_print_containers_cloud
  printf '\n'
  env_print_dev_environments
  printf '\n'
  env_print_backup_tools
  printf '\n'
}
