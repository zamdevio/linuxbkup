# shellcheck shell=bash

wslbkup_cmd_backup() {
  log_info "wslbkup ${WSLBKUP_VERSION} — backup"
  if [[ "${WSLBKUP_DRY_RUN:-0}" -eq 1 ]]; then
    log_info "dry-run enabled (no archive will be written once implemented)"
  fi
  wslbkup_phase_stub "2" "Backup"
  log_info "Planned: scan → report → user decisions → manifests + tar.zst to Windows Downloads by default."
}
