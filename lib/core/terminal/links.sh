# shellcheck shell=bash
# OSC 8 hyperlinks (file:// and https://) for capable terminals.

# Enable file/URL hyperlinks when stdout is a TTY and links are not disabled.
term_links_enabled() {
  [[ "${WSLBKUP_NO_LINKS:-0}" -eq 1 ]] && return 1
  [[ "${WSLBKUP_NO_COLOR:-0}" -eq 1 && "${WSLBKUP_FORCE_LINKS:-0}" -ne 1 ]] && return 1
  [[ -n "${NO_COLOR:-}" && "${WSLBKUP_FORCE_LINKS:-0}" -ne 1 ]] && return 1
  [[ -t 1 ]] || return 1
  return 0
}

# Percent-encode a path for file:// URLs (spaces + reserved chars).
term_urlencode_path() {
  local s="$1" out="" c hex
  local -i idx
  for ((idx = 0; idx < ${#s}; idx++)); do
    c="${s:idx:1}"
    case "${c}" in
      [A-Za-z0-9~_./+:-]) out+="${c}" ;;
      *)
        printf -v hex '%%%02X' "'${c}"
        out+="${hex}"
        ;;
    esac
  done
  printf '%s' "${out}"
}

# Emit OSC 8 hyperlink. Args: url display_text
# If links disabled, prints display_text only (no trailing newline).
term_link() {
  local url="$1" text="$2"
  if ! term_links_enabled; then
    printf '%s' "${text}"
    return 0
  fi
  printf '\033]8;;%s\033\\%s\033]8;;\033\\' "${url}" "${text}"
}

# Hyperlink a filesystem path. Args: path [display]
term_path_link() {
  local path="$1"
  local display="${2:-$1}"
  local abs encoded

  if [[ "${path}" != /* ]]; then
    abs="$(pwd -P)/${path}"
  else
    abs="${path}"
  fi
  if wslbkup_require_cmd realpath; then
    abs="$(realpath -m "${abs}" 2>/dev/null || printf '%s' "${abs}")"
  fi

  encoded="$(term_urlencode_path "${abs}")"
  term_link "file://${encoded}" "${display}"
}

# Hyperlink an https/http URL. Args: url [display]
term_url_link() {
  local url="$1"
  local display="${2:-$1}"
  term_link "${url}" "${display}"
}
