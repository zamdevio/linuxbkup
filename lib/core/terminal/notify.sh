# shellcheck shell=bash
# Best-effort completion notifications. Never required for correctness.

term_notify_enabled() {
  [[ "${LINUXBKUP_QUIET:-0}" -eq 1 ]] && return 1
  [[ "${LINUXBKUP_NO_NOTIFY:-0}" -eq 1 ]] && return 1
  return 0
}

# Args: title body
term_notify() {
  local title="${1:-linuxbkup}" body="${2:-done}"

  term_notify_enabled || return 0
  log_debug "notify: ${title} — ${body}"

  # Desktop (Linux) when available
  if command -v notify-send >/dev/null 2>&1; then
    notify-send --app-name=linuxbkup "${title}" "${body}" 2>/dev/null || true
    return 0
  fi

  # OSC 9 (iTerm2 / some terminals) — title only style
  if [[ -t 1 ]]; then
    printf '\033]9;%s: %s\007' "${title}" "${body}" 2>/dev/null || true
    # OSC 777 notify (Kitty / others)
    printf '\033]777;notify;%s;%s\007' "${title}" "${body}" 2>/dev/null || true
  fi
}
