# shellcheck shell=bash
# Structured console logging. Never print secret contents here.

_log_tag() {
  local level="$1"
  printf '[%s]' "${level}"
}

log_info() {
  [[ "${WSLBKUP_QUIET:-0}" -eq 1 ]] && return 0
  printf '%s %s\n' "$(_log_tag INFO)" "$*"
}

log_ok() {
  [[ "${WSLBKUP_QUIET:-0}" -eq 1 ]] && return 0
  printf '%s %s\n' "$(_log_tag OK)" "$*"
}

log_warn() {
  printf '%s %s\n' "$(_log_tag WARN)" "$*" >&2
}

log_skip() {
  [[ "${WSLBKUP_QUIET:-0}" -eq 1 ]] && return 0
  printf '%s %s\n' "$(_log_tag SKIP)" "$*"
}

log_fatal() {
  printf '%s %s\n' "$(_log_tag FATAL)" "$*" >&2
}

log_debug() {
  [[ "${WSLBKUP_VERBOSE:-0}" -eq 1 ]] || return 0
  printf '%s %s\n' "$(_log_tag DEBUG)" "$*" >&2
}
