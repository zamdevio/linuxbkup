# shellcheck shell=bash
# ANSI styling + structured logging. Quiet / professional.
# Loads links + control helpers for the terminal package.

# shellcheck source=lib/core/terminal/links.sh
source "${LINUXBKUP_ROOT}/lib/core/terminal/links.sh"
# shellcheck source=lib/core/terminal/control.sh
source "${LINUXBKUP_ROOT}/lib/core/terminal/control.sh"

_ui_init() {
  LINUXBKUP_COLOR=0
  if [[ "${LINUXBKUP_NO_COLOR:-0}" -eq 1 || -n "${NO_COLOR:-}" ]]; then
    LINUXBKUP_COLOR=0
  elif [[ -t 1 && -t 2 ]]; then
    LINUXBKUP_COLOR=1
  fi

  if [[ "${LINUXBKUP_COLOR}" -eq 1 ]]; then
    UI_RESET=$'\033[0m'
    UI_DIM=$'\033[2m'
    UI_BOLD=$'\033[1m'
    UI_RED=$'\033[31m'
    UI_GREEN=$'\033[32m'
    UI_YELLOW=$'\033[33m'
    UI_BLUE=$'\033[34m'
    UI_CYAN=$'\033[36m'
  else
    UI_RESET="" UI_DIM="" UI_BOLD=""
    UI_RED="" UI_GREEN="" UI_YELLOW="" UI_BLUE="" UI_CYAN=""
  fi
}

_ui_ensure() {
  [[ -n "${LINUXBKUP_COLOR+x}" && -n "${UI_RESET+x}" ]] || _ui_init
}

_log_tag() {
  local level="$1" color="$2"
  _ui_ensure
  printf '%s[%s]%s' "${color}" "${level}" "${UI_RESET}"
}

log_info() {
  [[ "${LINUXBKUP_QUIET:-0}" -eq 1 ]] && return 0
  _ui_ensure
  printf '%s %s\n' "$(_log_tag INFO "${UI_BLUE}")" "$*"
}

log_ok() {
  [[ "${LINUXBKUP_QUIET:-0}" -eq 1 ]] && return 0
  _ui_ensure
  printf '%s %s\n' "$(_log_tag OK "${UI_GREEN}")" "$*"
}

log_warn() {
  _ui_ensure
  printf '%s %s\n' "$(_log_tag WARN "${UI_YELLOW}")" "$*" >&2
}

log_skip() {
  [[ "${LINUXBKUP_QUIET:-0}" -eq 1 ]] && return 0
  _ui_ensure
  printf '%s %s\n' "$(_log_tag SKIP "${UI_DIM}")" "$*"
}

log_fatal() {
  _ui_ensure
  printf '%s %s\n' "$(_log_tag FATAL "${UI_RED}")" "$*" >&2
}

log_debug() {
  [[ "${LINUXBKUP_VERBOSE:-0}" -eq 1 ]] || return 0
  _ui_ensure
  printf '%s %s\n' "$(_log_tag DEBUG "${UI_DIM}")" "$*" >&2
}

ui_rule() {
  _ui_ensure
  printf '%s────────────────────────────────────────%s\n' "${UI_DIM}" "${UI_RESET}"
}

ui_heading() {
  _ui_ensure
  printf '\n%s%s%s\n' "${UI_BOLD}" "$*" "${UI_RESET}"
  ui_rule
}

ui_section() {
  _ui_ensure
  printf '%s%s%s\n' "${UI_BOLD}" "$*" "${UI_RESET}"
}

ui_kv() {
  local key="$1" value="$2"
  _ui_ensure
  printf '  %s%-14s%s %s\n' "${UI_DIM}" "${key}" "${UI_RESET}" "${value}"
}

# Like ui_kv but value is rendered as a clickable file path (OSC 8).
ui_kv_path() {
  local key="$1" path="$2"
  local linked
  _ui_ensure
  linked="$(term_path_link "${path}")"
  printf '  %s%-14s%s %s\n' "${UI_DIM}" "${key}" "${UI_RESET}" "${linked}"
}

ui_item() {
  # ui_item ok|warn|off|note <text>
  local kind="$1"
  shift
  _ui_ensure
  case "${kind}" in
    ok)   printf '  %s✓%s %s\n' "${UI_GREEN}" "${UI_RESET}" "$*" ;;
    warn) printf '  %s~%s %s\n' "${UI_YELLOW}" "${UI_RESET}" "$*" ;;
    off)  printf '  %s-%s %s\n' "${UI_DIM}" "${UI_RESET}" "$*" ;;
    note) printf '  %s·%s %s\n' "${UI_CYAN}" "${UI_RESET}" "$*" ;;
    *)    printf '  %s\n' "$*" ;;
  esac
}

# ui_item_path ok|warn|off|note <path> [suffix text]
ui_item_path() {
  local kind="$1" path="$2"
  local suffix="${3:-}"
  local linked
  _ui_ensure
  linked="$(term_path_link "${path}")"
  if [[ -n "${suffix}" ]]; then
    ui_item "${kind}" "${linked}  ${suffix}"
  else
    ui_item "${kind}" "${linked}"
  fi
}
