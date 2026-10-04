# shellcheck shell=bash

wslbkup_cmd_list() {
  if cmd_want_help "$@"; then
    wslbkup_cmd_help list
    return 0
  fi

  local backup="${1:-}"
  if [[ -z "${backup}" ]]; then
    log_fatal "Usage: wslbkup list <backup>"
    wslbkup_cmd_help list
    return 2
  fi

  # shellcheck source=lib/core/context.sh
  source "${WSLBKUP_ROOT}/lib/core/context.sh"

  cmd_context_begin list \
    --desc "List backup contents at a high level (not fully implemented yet)." \
    --required tar zstd \
    --optional sha256sum

  ui_kv "Archive" "${backup}"
  wslbkup_phase_stub "2" "List"
}
