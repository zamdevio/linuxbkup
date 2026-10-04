# shellcheck shell=bash
# Low-level terminal control sequences (CSI / OSC helpers).

# Soft reset of styling (also clears OSC 8 if a link was left open).
term_reset() {
  _ui_ensure
  printf '%s\033]8;;\033\\' "${UI_RESET}"
}

# Clear from cursor to end of line.
term_clear_eol() {
  printf '\033[K'
}

# Hide / show cursor (best-effort; no-op when not a TTY).
term_cursor_hide() {
  [[ -t 1 ]] || return 0
  printf '\033[?25l'
}

term_cursor_show() {
  [[ -t 1 ]] || return 0
  printf '\033[?25h'
}
