# shellcheck shell=bash

wslbkup_cmd_restore() {
  if cmd_want_help "$@"; then
    wslbkup_cmd_help restore
    return 0
  fi

  local backup="${1:-}"
  if [[ -z "${backup}" ]]; then
    log_fatal "Usage: wslbkup restore <backup>"
    wslbkup_cmd_help restore
    return 2
  fi

  # shellcheck source=lib/core/context.sh
  source "${WSLBKUP_ROOT}/lib/core/context.sh"

  cmd_context_begin restore \
    --desc "Reconstruct environment from a backup (not fully implemented yet)." \
    --required tar zstd rsync sha256sum \
    --optional age

  ui_kv "Archive" "${backup}"
  wslbkup_phase_stub "4" "Restore"
}
