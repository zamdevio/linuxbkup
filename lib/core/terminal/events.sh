# shellcheck shell=bash
# Structured step events (phase 08.10). Human labels stay on ui_step;
# this emits machine-readable lines for verbose/debug + optional jsonl file.

LINUXBKUP_EVENTS_FILE="${LINUXBKUP_EVENTS_FILE:-}"
LINUXBKUP_EVENT_TS0="${LINUXBKUP_EVENT_TS0:-}"

# Begin an event stream. Args: [jsonl_path] — empty = no file, still log_verbose.
linuxbkup_events_begin() {
  LINUXBKUP_EVENTS_FILE="${1:-}"
  LINUXBKUP_EVENT_TS0="$(date +%s)"
  if [[ -n "${LINUXBKUP_EVENTS_FILE}" ]]; then
    mkdir -p "$(dirname -- "${LINUXBKUP_EVENTS_FILE}")" 2>/dev/null || true
    : >"${LINUXBKUP_EVENTS_FILE}"
  fi
}

linuxbkup_events_end() {
  LINUXBKUP_EVENTS_FILE=""
}

# Stop writing the jsonl file (verbose/debug events continue). Use before stage
# cleanup so pack/summary cannot race a deleted path.
linuxbkup_events_detach_file() {
  LINUXBKUP_EVENTS_FILE=""
}

# Escape a value for a minimal JSON string (no newlines).
_linuxbkup_event_json_str() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/ }"
  s="${s//$'\r'/ }"
  printf '%s' "${s}"
}

# linuxbkup_event <phase> <step_id> [k=v ...]
# phase: start | ok | fail | skip
linuxbkup_event() {
  local phase="$1" step="$2"
  shift 2 || true
  local now ts elapsed=0 line extra="" pair key val

  now="$(date +%s)"
  if [[ -n "${LINUXBKUP_EVENT_TS0:-}" ]]; then
    elapsed=$((now - LINUXBKUP_EVENT_TS0))
  fi
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%S)"

  line="{\"event\":\"step\",\"phase\":\"$(_linuxbkup_event_json_str "${phase}")\",\"step\":\"$(_linuxbkup_event_json_str "${step}")\",\"ts\":\"${ts}\",\"elapsed_s\":${elapsed}"
  for pair in "$@"; do
    [[ "${pair}" == *=* ]] || continue
    key="${pair%%=*}"
    val="${pair#*=}"
    [[ "${key}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
    line+=",\"$(_linuxbkup_event_json_str "${key}")\":\"$(_linuxbkup_event_json_str "${val}")\""
    extra+=" ${key}=${val}"
  done
  line+="}"

  if [[ -n "${LINUXBKUP_EVENTS_FILE:-}" ]]; then
    local _ev_dir
    _ev_dir="$(dirname -- "${LINUXBKUP_EVENTS_FILE}")"
    if [[ -d "${_ev_dir}" ]]; then
      printf '%s\n' "${line}" >>"${LINUXBKUP_EVENTS_FILE}" 2>/dev/null || true
    fi
  fi

  case "${phase}" in
    start) log_verbose "event start ${step}${extra}" ;;
    ok) log_verbose "event ok ${step}${extra}" ;;
    fail) log_verbose "event fail ${step}${extra}" ;;
    skip) log_verbose "event skip ${step}${extra}" ;;
    *) log_debug "event ${phase} ${step}${extra}" ;;
  esac
  log_debug "event.json ${line}"
}

# ui_step + event start in one call.
# Args: n total step_id label
ui_step_event() {
  local n="$1" total="$2" step_id="$3" label="$4"
  ui_step "${n}" "${total}" "${label}"
  linuxbkup_event start "${step_id}" "n=${n}" "total=${total}" "label=${label}"
}
