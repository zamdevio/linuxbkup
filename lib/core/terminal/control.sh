# shellcheck shell=bash
# CSI / OSC helpers. Live status paints on stderr so stdout stays pipe-clean.

# Soft reset of styling (also clears OSC 8 if a link was left open).
term_reset() {
  _ui_ensure
  printf '%s\033]8;;\033\\' "${UI_RESET}" >&2
}

# Clear from cursor to end of line (stderr).
term_clear_eol() {
  printf '\033[K' >&2
}

# CR + erase whole line (EL2) — wipe a live status row before redraw/park.
term_clear_line() {
  printf '\r\033[2K' >&2
}

_term_tty_ok() {
  [[ -c /dev/tty ]] || return 1
  ( : >/dev/tty ) 2>/dev/null
}

# Prefer /dev/tty so restore works when stdout/stderr are redirected.
term_cursor_hide() {
  if _term_tty_ok; then
    printf '\033[?25l' >/dev/tty 2>/dev/null || true
  elif [[ -t 2 ]]; then
    printf '\033[?25l' >&2
  fi
}

term_cursor_show() {
  if _term_tty_ok; then
    printf '\033[?25h' >/dev/tty 2>/dev/null || true
  elif [[ -t 2 ]]; then
    printf '\033[?25h' >&2
  else
    printf '\033[?25h' 2>/dev/null || true
  fi
  if command -v tput >/dev/null 2>&1; then
    if _term_tty_ok; then
      tput cnorm >/dev/tty 2>/dev/null || true
    else
      tput cnorm 2>/dev/null || true
    fi
  fi
}

linuxbkup_tty_restore() {
  declare -F term_live_park >/dev/null 2>&1 && term_live_park
  term_cursor_show
}

TERM_LIVE_ACTIVE="${TERM_LIVE_ACTIVE:-0}"

# Clear the live row so a durable log line can print; next update redraws.
term_live_park() {
  if [[ "${TERM_LIVE_ACTIVE:-0}" -eq 1 ]]; then
    term_clear_line
    TERM_LIVE_ACTIVE=0
    term_cursor_show
  fi
}
