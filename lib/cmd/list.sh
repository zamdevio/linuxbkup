# shellcheck shell=bash

linuxbkup_cmd_list() {
  if cmd_want_help "$@"; then
    linuxbkup_cmd_help list
    return 0
  fi

  local backup="${1:-}"
  if [[ -z "${backup}" ]]; then
    log_fatal "Usage: linuxbkup list <backup>"
    linuxbkup_cmd_help list
    return 2
  fi

  # shellcheck source=lib/core/context.sh
  source "${LINUXBKUP_ROOT}/lib/core/context.sh"

  cmd_context_begin list \
    --desc "List backup contents at a high level (not fully implemented yet)." \
    --required tar zstd \
    --optional sha256sum

  ui_kv "Archive" "${backup}"
  linuxbkup_phase_stub "2" "List"
}
