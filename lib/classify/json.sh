# shellcheck shell=bash
# Stable JSON plan envelope for agents (plan --json).

_json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "${s}"
}

# Emit JSON object to stdout. Args: home
classify_print_plan_json() {
  local home="$1"
  local path class action size reason size_h size_b
  local n_un=0 n_in=0 n_sk=0 n_se=0 n_ask=0
  local -a entries=()
  local first=1
  local generated json_action=""
  local _json_tmp

  generated="$(date -Iseconds 2>/dev/null || date)"
  _json_tmp="$(mktemp "${TMPDIR:-/tmp}/linuxbkup-planj.XXXXXX")" || return 1

  while true; do
    linuxbkup_op_begin "classify" "" 0 1
    entries=()
    n_un=0 n_in=0 n_sk=0 n_se=0 n_ask=0
    classify_scan_home "${home}" >"${_json_tmp}" || true
    while IFS=$'\t' read -r path class action size reason; do
      [[ -z "${path:-}" ]] && continue
      case "${class}" in
        unexpected) n_un=$((n_un + 1)) ;;
        secret) n_se=$((n_se + 1)) ;;
        skip) n_sk=$((n_sk + 1)) ;;
        include) n_in=$((n_in + 1)) ;;
      esac
      [[ "${action}" == "ask" ]] && n_ask=$((n_ask + 1))
      # size column is bytes; expose human in JSON for readability + size_bytes
      size_h="${size}"
      size_b=""
      if [[ "${size}" =~ ^[0-9]+$ ]]; then
        size_b="${size}"
        if declare -F fs_bytes_human >/dev/null 2>&1; then
          size_h="$(fs_bytes_human "${size}")"
        fi
      fi
      if [[ -n "${size_b}" ]]; then
        entries+=("$(printf '{"path":"%s","class":"%s","action":"%s","size":"%s","size_bytes":%s,"reason":"%s"}' \
          "$(_json_escape "${path}")" \
          "$(_json_escape "${class}")" \
          "$(_json_escape "${action}")" \
          "$(_json_escape "${size_h}")" \
          "${size_b}" \
          "$(_json_escape "${reason}")")")
      else
        entries+=("$(printf '{"path":"%s","class":"%s","action":"%s","size":"%s","reason":"%s"}' \
          "$(_json_escape "${path}")" \
          "$(_json_escape "${class}")" \
          "$(_json_escape "${action}")" \
          "$(_json_escape "${size_h}")" \
          "$(_json_escape "${reason}")")")
      fi
    done <"${_json_tmp}"

    if linuxbkup_interrupt_resolve; then
      json_action="${LINUXBKUP_INTERRUPT_RESULT}"
      case "${json_action}" in
        retry|continue|skip)
          linuxbkup_op_end
          continue
          ;;
        *)
          linuxbkup_op_end
          rm -f "${_json_tmp}"
          return 1
          ;;
      esac
    fi
    linuxbkup_op_end
    break
  done
  rm -f "${_json_tmp}"

  printf '{\n'
  printf '  "schema": "linuxbkup.plan/v1",\n'
  printf '  "version": "%s",\n' "$(_json_escape "${LINUXBKUP_VERSION}")"
  printf '  "home": "%s",\n' "$(_json_escape "${home}")"
  printf '  "generated": "%s",\n' "$(_json_escape "${generated}")"
  printf '  "summary": {\n'
  printf '    "include": %d,\n' "${n_in}"
  printf '    "secret": %d,\n' "${n_se}"
  printf '    "skip": %d,\n' "${n_sk}"
  printf '    "unexpected": %d,\n' "${n_un}"
  printf '    "ask": %d\n' "${n_ask}"
  printf '  },\n'
  printf '  "entries": [\n'
  first=1
  local e
  for e in "${entries[@]+"${entries[@]}"}"; do
    if [[ "${first}" -eq 1 ]]; then
      first=0
      printf '    %s' "${e}"
    else
      printf ',\n    %s' "${e}"
    fi
  done
  [[ "${first}" -eq 0 ]] && printf '\n'
  printf '  ]\n'
  printf '}\n'
}
