# shellcheck shell=bash

wslbkup_cmd_verify() {
  local backup="${1:-}"
  log_info "wslbkup ${WSLBKUP_VERSION} — verify"
  if [[ -z "${backup}" ]]; then
    log_fatal "Usage: wslbkup verify <backup>"
    return 2
  fi
  wslbkup_phase_stub "2" "Verify"
  log_info "Target backup argument: ${backup}"
}
