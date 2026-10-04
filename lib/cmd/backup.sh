# shellcheck shell=bash

wslbkup_cmd_backup() {
  if cmd_want_help "$@"; then
    wslbkup_cmd_help backup
    return 0
  fi

  # shellcheck source=lib/core/context.sh
  source "${WSLBKUP_ROOT}/lib/core/context.sh"

  cmd_context_begin backup \
    --desc "Create an intelligent backup archive (not fully implemented yet)." \
    --required tar zstd rsync du sha256sum \
    --optional age

  wslbkup_phase_stub "2" "Backup"
  log_info "Planned: scan → report → decisions → manifests + tar.zst → Windows Downloads."
}
