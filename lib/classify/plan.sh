# shellcheck shell=bash
# Human / machine plan output from classify_scan_home.

# shellcheck source=lib/classify/scan.sh
source "${LINUXBKUP_ROOT}/lib/classify/scan.sh"
# shellcheck source=lib/classify/json.sh
source "${LINUXBKUP_ROOT}/lib/classify/json.sh"
# shellcheck source=lib/fs/sizes.sh
source "${LINUXBKUP_ROOT}/lib/fs/sizes.sh"

# Append sortable display row: bytes<TAB>display-line (large→small when printed).
_classify_plan_push_row() {
  local -n _arr="$1"
  local size="$2" action="$3" path="$4" reason="$5"
  local bytes=0 line
  bytes="$(fs_parse_size_to_bytes "${size}" 2>/dev/null || printf '0')"
  [[ "${bytes}" =~ ^[0-9]+$ ]] || bytes=0
  line="$(printf '  %8s  %-10s  %s  (%s)' "${size}" "${action}" "$(term_path_link "${path}")" "${reason}")"
  _arr+=("$(printf '%s\t%s' "${bytes}" "${line}")")
}

_classify_plan_print_sorted() {
  local -n _arr="$1"
  local label="$2"
  if [[ "${#_arr[@]}" -eq 0 ]]; then
    ui_item note "none"
    return 0
  fi
  printf '%s\n' "${_arr[@]}" | sort -t$'\t' -k1,1nr | cut -f2- | constraints_list_apply
  constraints_list_footer "${label}"
}

# Print classification plan (human). Args: home
classify_print_plan() {
  local home="$1"
  local path class action size reason
  local -a unexpected=() include_rows=() skip_rows=() secret_rows=()
  local n_un=0 n_in=0 n_sk=0 n_se=0

  ui_section "Home classification plan"
  ui_item note "Shallow scan of \$HOME + ~/.local/* — what backup would copy"
  ui_item note "Lists ordered large → small when sizes are known"
  printf '\n'

  if [[ "${LINUXBKUP_INSPECT_QUICK:-0}" -eq 1 ]]; then
    ui_item note "sizes omitted (pass -v for filter-aware sizes)"
  fi

  while IFS=$'\t' read -r path class action size reason; do
    [[ -z "${path:-}" ]] && continue
    log_debug "plan row class=${class} action=${action} path=${path} reason=${reason}"
    case "${class}" in
      unexpected)
        _classify_plan_push_row unexpected "${size}" "${action}" "${path}" "${reason}"
        n_un=$((n_un + 1))
        ;;
      secret)
        _classify_plan_push_row secret_rows "${size}" "${action}" "${path}" "${reason}"
        n_se=$((n_se + 1))
        ;;
      skip)
        _classify_plan_push_row skip_rows "${size}" "${action}" "${path}" "${reason}"
        n_sk=$((n_sk + 1))
        ;;
      include)
        _classify_plan_push_row include_rows "${size}" "${action}" "${path}" "${reason}"
        n_in=$((n_in + 1))
        ;;
    esac
  done < <(classify_scan_home "${home}")

  printf '  Known include (%d):\n' "${n_in}"
  _classify_plan_print_sorted include_rows "known include"

  printf '  Secrets (%d):\n' "${n_se}"
  _classify_plan_print_sorted secret_rows "secrets"

  printf '  Skip / regenerable (%d):\n' "${n_sk}"
  _classify_plan_print_sorted skip_rows "skip"

  printf '  Unexpected (%d):\n' "${n_un}"
  _classify_plan_print_sorted unexpected "unexpected"
  if [[ "${n_un}" -gt 0 ]]; then
    if [[ "${LINUXBKUP_YES:-0}" -eq 1 ]] || [[ ! -t 0 ]]; then
      ui_item note "unexpected → auto-include (--yes or non-TTY)"
    else
      ui_item note "unexpected → ask on backup (pass -y to auto-include)"
    fi
  fi

  log_verbose "plan counts include=${n_in} secret=${n_se} skip=${n_sk} unexpected=${n_un}"
}

# Short end-of-backup summary (not a full plan dump).
classify_print_backup_summary() {
  local home="$1"
  local path class action size reason
  local n_un=0 n_in=0 n_sk=0 n_se=0 n_copy=0

  while IFS=$'\t' read -r path class action size reason; do
    [[ -z "${path:-}" ]] && continue
    case "${class}" in
      unexpected) n_un=$((n_un + 1)) ;;
      secret) n_se=$((n_se + 1)) ;;
      skip) n_sk=$((n_sk + 1)) ;;
      include) n_in=$((n_in + 1)) ;;
    esac
    [[ "${action}" == "include" || ( "${action}" == "ask" && "${LINUXBKUP_CLASSIFY_INCLUDE_ASK:-0}" -eq 1 ) ]] && n_copy=$((n_copy + 1))
  done < <(classify_scan_home "${home}")

  ui_section "Backup summary"
  ui_kv "Copy candidates" "${n_copy}"
  ui_kv "Known include" "${n_in}"
  ui_kv "Secrets" "${n_se}"
  ui_kv "Skipped" "${n_sk}"
  ui_kv "Unexpected" "${n_un}"
  if [[ "${LINUXBKUP_PERM_SKIPS:-0}" -gt 0 ]]; then
    ui_kv "Soft-skips" "${LINUXBKUP_PERM_SKIPS} (permission/partial)"
  fi
  linuxbkup_tip_run plan
  local -a _json_flags=()
  linuxbkup_flags_plan_relevant _json_flags
  if [[ "${#_json_flags[@]}" -gt 0 ]]; then
    ui_item note "JSON:  linuxbkup ${_json_flags[*]} plan --json"
  else
    ui_item note "JSON:  linuxbkup plan --json"
  fi
}
