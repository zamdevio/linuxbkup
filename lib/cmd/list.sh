# shellcheck shell=bash

wslbkup_cmd_list() {
  local backup="${1:-}"
  log_info "wslbkup ${WSLBKUP_VERSION} — list"
  if [[ -z "${backup}" ]]; then
    log_fatal "Usage: wslbkup list <backup>"
    return 2
  fi
  wslbkup_phase_stub "2" "List"
  log_info "Target backup argument: ${backup}"
}
