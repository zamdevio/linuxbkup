# shellcheck shell=bash

wslbkup_cmd_inspect() {
  log_info "wslbkup ${WSLBKUP_VERSION} — inspect"
  wslbkup_phase_stub "1" "Environment inspection"
  log_info "Planned: distro/arch/WSL, users, package managers, du large-item report, Downloads path preview."
}
