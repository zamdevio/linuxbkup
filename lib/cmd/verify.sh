# shellcheck shell=bash

wslbkup_cmd_verify() {
  if cmd_want_help "$@"; then
    wslbkup_cmd_help verify
    return 0
  fi

  local backup="${1:-}"
  if [[ -z "${backup}" ]]; then
    log_fatal "Usage: wslbkup verify <backup>"
    wslbkup_cmd_help verify
    return 2
  fi

  # shellcheck source=lib/core/context.sh
  source "${WSLBKUP_ROOT}/lib/core/context.sh"

  cmd_context_begin verify \
    --desc "Verify archive integrity / manifests (not fully implemented yet)." \
    --required tar zstd sha256sum \
    --optional age

  ui_kv "Archive" "${backup}"
  wslbkup_phase_stub "2" "Verify"
}
