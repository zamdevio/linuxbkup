# shellcheck shell=bash
# Live progress line for long-running ops (TTY). Non-TTY → INFO steps.
# Rich extras: optional staging footprint + max-size headroom + ETA.

TERM_PROGRESS_ACTIVE=0
TERM_PROGRESS_TOTAL=0
TERM_PROGRESS_CUR=0
TERM_PROGRESS_LABEL=""
TERM_PROGRESS_STAGE=""
TERM_PROGRESS_STAGE_BYTES=0
TERM_PROGRESS_T0=0
TERM_PROGRESS_EXTRA=""

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

# Format seconds → compact human (e.g. 12s, 3m12s, 1h05m).
term_progress_fmt_duration() {
  local sec="${1:-0}"
  local h=0 m=0 s=0
  [[ "${sec}" =~ ^[0-9]+$ ]] || sec=0
  ((sec < 0)) && sec=0
  h=$((sec / 3600))
  m=$(((sec % 3600) / 60))
  s=$((sec % 60))
  if [[ "${h}" -gt 0 ]]; then
    printf '%dh%02dm' "${h}" "${m}"
  elif [[ "${m}" -gt 0 ]]; then
    printf '%dm%02ds' "${m}" "${s}"
  else
    printf '%ds' "${s}"
  fi
}

# Track a staging directory for live size on the bar. Args: [dir]
term_progress_set_stage() {
  TERM_PROGRESS_STAGE="${1:-}"
  TERM_PROGRESS_STAGE_BYTES=0
}

# Optional static suffix (e.g. "4w"). Cleared on end.
term_progress_set_extra() {
  TERM_PROGRESS_EXTRA="${1:-}"
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
  TERM_PROGRESS_T0="$(date +%s)"

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

# Update. Args: current [path_label] [item_size_human]
# Example: 19%  19/96  path (713M) · ETA 1m12s · 4w · stage 5.1GB
term_progress_update() {
  local cur="$1" label="${2:-}" item_h="${3:-}"
  local pct=0 width=28 filled empty i bar
  local short stage_h="" max_h="" mid="" extra=""
  local now elapsed eta_sec

  TERM_PROGRESS_CUR="${cur}"
  [[ -n "${label}" ]] && TERM_PROGRESS_LABEL="${label}"

  if [[ "${TERM_PROGRESS_TOTAL}" -gt 0 ]]; then
    pct=$((cur * 100 / TERM_PROGRESS_TOTAL))
    ((pct > 100)) && pct=100
  fi

  short="$(term_progress_truncate "${label}" 36)"
  if [[ -n "${short}" ]]; then
    mid="${short}"
    if [[ -n "${item_h}" && "${item_h}" != "?" ]]; then
      mid+=" (${item_h})"
    fi
  fi

  # ETA from elapsed / completion ratio (after a few items so rate stabilizes)
  now="$(date +%s)"
  elapsed=$((now - TERM_PROGRESS_T0))
  if [[ "${cur}" -ge 3 && "${TERM_PROGRESS_TOTAL}" -gt 0 && "${elapsed}" -gt 0 && "${cur}" -lt "${TERM_PROGRESS_TOTAL}" ]]; then
    eta_sec=$(((TERM_PROGRESS_TOTAL - cur) * elapsed / cur))
    extra=" · ETA $(term_progress_fmt_duration "${eta_sec}")"
  elif [[ "${cur}" -ge "${TERM_PROGRESS_TOTAL}" && "${TERM_PROGRESS_TOTAL}" -gt 0 && "${elapsed}" -gt 0 ]]; then
    extra=" · $(term_progress_fmt_duration "${elapsed}")"
  fi
  if [[ -n "${TERM_PROGRESS_EXTRA}" ]]; then
    extra+=" · ${TERM_PROGRESS_EXTRA}"
  fi

  if [[ -n "${TERM_PROGRESS_STAGE}" ]]; then
    # Throttle stage du: every 8 updates or first/last
    if [[ "${cur}" -le 1 || "${cur}" -ge "${TERM_PROGRESS_TOTAL}" || $((cur % 8)) -eq 0 ]]; then
      term_progress_sample_stage >/dev/null || true
    fi
    if declare -F fs_bytes_human >/dev/null 2>&1; then
      stage_h="$(fs_bytes_human "${TERM_PROGRESS_STAGE_BYTES}")"
    else
      stage_h="${TERM_PROGRESS_STAGE_BYTES}B"
    fi
    extra+=" · stage ${stage_h}"
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
        log_info "progress ${cur}/${TERM_PROGRESS_TOTAL} ${mid}${extra}"
      fi
    fi
    return 0
  fi

  filled=$((pct * width / 100))
  empty=$((width - filled))
  bar=""
  for ((i = 0; i < filled; i++)); do bar+="█"; done
  for ((i = 0; i < empty; i++)); do bar+="░"; done

  _ui_ensure
  printf '\r  %s[%s]%s %3d%%  %s/%s  %s%s' \
    "${UI_DIM}" "${bar}" "${UI_RESET}" \
    "${pct}" "${cur}" "${TERM_PROGRESS_TOTAL}" "${mid}" "${extra}"
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
  TERM_PROGRESS_EXTRA=""
  TERM_PROGRESS_T0=0
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
