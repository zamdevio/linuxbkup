# shellcheck shell=bash

wslbkup_cmd_restore() {
  local backup="${1:-}"
  log_info "wslbkup ${WSLBKUP_VERSION} — restore"
  if [[ -z "${backup}" ]]; then
    log_fatal "Usage: wslbkup restore <backup>"
    return 2
  fi
  if [[ "${WSLBKUP_DRY_RUN:-0}" -eq 1 ]]; then
    log_info "dry-run enabled (no system changes once implemented)"
  fi
  wslbkup_phase_stub "4" "Restore"
  log_info "Target backup argument: ${backup}"
}
