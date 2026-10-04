# shellcheck shell=bash
# Live progress line for long-running ops (TTY). Non-TTY → INFO steps.
# Rich extras: optional staging footprint + max-size headroom on the bar.

TERM_PROGRESS_ACTIVE=0
TERM_PROGRESS_TOTAL=0
TERM_PROGRESS_CUR=0
TERM_PROGRESS_LABEL=""
TERM_PROGRESS_STAGE=""
TERM_PROGRESS_STAGE_BYTES=0

term_progress_enabled() {
  [[ "${LINUXBKUP_QUIET:-0}" -eq 1 ]] && return 1
  [[ -t 1 ]] || return 1
  return 0
}

term_progress_truncate() {
  local s="$1" max="${2:-48}"
  if [[ ${#s} -le "${max}" ]]; then
    printf '%s' "${s}"
    return 0
  fi
  printf '…%s' "${s:$((${#s} - max + 1))}"
}

# Track a staging directory for live size on the bar. Args: [dir]
term_progress_set_stage() {
  TERM_PROGRESS_STAGE="${1:-}"
  TERM_PROGRESS_STAGE_BYTES=0
}

# Sample stage bytes (updates TERM_PROGRESS_STAGE_BYTES). Prints bytes.
term_progress_sample_stage() {
  local b=0
  if [[ -n "${TERM_PROGRESS_STAGE}" && -d "${TERM_PROGRESS_STAGE}" ]]; then
    if declare -F fs_dir_bytes >/dev/null 2>&1; then
      b="$(fs_dir_bytes "${TERM_PROGRESS_STAGE}")" || b=0
    else
      b="$(du -sb "${TERM_PROGRESS_STAGE}" 2>/dev/null | awk '{print $1; exit}')" || b=0
    fi
  fi
  [[ "${b}" =~ ^[0-9]+$ ]] || b=0
  TERM_PROGRESS_STAGE_BYTES="${b}"
  printf '%s\n' "${b}"
}

# Begin a progress sequence. Args: total [title]
term_progress_begin() {
  TERM_PROGRESS_TOTAL="${1:-0}"
  TERM_PROGRESS_CUR=0
  TERM_PROGRESS_LABEL="${2:-}"
  TERM_PROGRESS_ACTIVE=0
  TERM_PROGRESS_STAGE_BYTES=0

  if ! term_progress_enabled; then
    [[ -n "${TERM_PROGRESS_LABEL}" ]] && log_info "${TERM_PROGRESS_LABEL} (0/${TERM_PROGRESS_TOTAL})"
    return 0
  fi

  TERM_PROGRESS_ACTIVE=1
  term_cursor_hide
  if [[ -n "${TERM_PROGRESS_LABEL}" ]]; then
    printf '  %s\n' "${TERM_PROGRESS_LABEL}"
  fi
}

# Update. Args: current [label]
term_progress_update() {
  local cur="$1" label="${2:-}"
  local pct=0 width=28 filled empty i bar
  local short stage_h="" max_h="" extra=""

  TERM_PROGRESS_CUR="${cur}"
  [[ -n "${label}" ]] && TERM_PROGRESS_LABEL="${label}"

  if [[ "${TERM_PROGRESS_TOTAL}" -gt 0 ]]; then
    pct=$((cur * 100 / TERM_PROGRESS_TOTAL))
    ((pct > 100)) && pct=100
  fi

  if [[ -n "${TERM_PROGRESS_STAGE}" ]]; then
    term_progress_sample_stage >/dev/null || true
    if declare -F fs_bytes_human >/dev/null 2>&1; then
      stage_h="$(fs_bytes_human "${TERM_PROGRESS_STAGE_BYTES}")"
    else
      stage_h="${TERM_PROGRESS_STAGE_BYTES}B"
    fi
    extra="  stage ${stage_h}"
    if [[ -n "${LINUXBKUP_MAX_SIZE_BYTES:-}" && "${LINUXBKUP_MAX_SIZE_BYTES}" -gt 0 ]]; then
      if declare -F fs_bytes_human >/dev/null 2>&1; then
        max_h="$(fs_bytes_human "${LINUXBKUP_MAX_SIZE_BYTES}")"
      else
        max_h="${LINUXBKUP_MAX_SIZE_BYTES}B"
      fi
      extra+=" / max ${max_h}"
    fi
  fi

  if ! term_progress_enabled || [[ "${TERM_PROGRESS_ACTIVE}" -ne 1 ]]; then
    if [[ "${LINUXBKUP_QUIET:-0}" -ne 1 ]]; then
      if [[ "${TERM_PROGRESS_TOTAL}" -le 20 ]] || (( cur == TERM_PROGRESS_TOTAL || cur % 5 == 0 )); then
        log_info "progress ${cur}/${TERM_PROGRESS_TOTAL} ${label}${extra}"
      fi
    fi
    return 0
  fi

  filled=$((pct * width / 100))
  empty=$((width - filled))
  bar=""
  for ((i = 0; i < filled; i++)); do bar+="█"; done
  for ((i = 0; i < empty; i++)); do bar+="░"; done
  short="$(term_progress_truncate "${label}" 36)"

  _ui_ensure
  printf '\r  %s[%s]%s %3d%%  %s/%s  %s%s' \
    "${UI_DIM}" "${bar}" "${UI_RESET}" \
    "${pct}" "${cur}" "${TERM_PROGRESS_TOTAL}" "${short}" "${extra}"
  term_clear_eol
}

# Finish progress line (newline + show cursor).
term_progress_end() {
  if [[ "${TERM_PROGRESS_ACTIVE}" -eq 1 ]]; then
    printf '\n'
    term_cursor_show
  fi
  TERM_PROGRESS_ACTIVE=0
  TERM_PROGRESS_STAGE=""
  TERM_PROGRESS_STAGE_BYTES=0
}

# One-shot spinner-ish status (no total). Args: message
term_progress_status() {
  local msg="$1"
  if term_progress_enabled; then
    _ui_ensure
    printf '\r  %s·%s %s' "${UI_CYAN}" "${UI_RESET}" "$(term_progress_truncate "${msg}" 72)"
    term_clear_eol
  else
    log_info "${msg}"
  fi
}
