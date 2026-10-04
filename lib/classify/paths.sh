# shellcheck shell=bash
# Classification using lib/constraints/* (no hardcoded path lists here).

classify_print_summary() {
  local home="$1"
  local p size path
  local regen_hits=0 sens=0 important_hits=0
  local -a rows=()

  ui_section "Classification hints (heuristic — review before backup)"

  _classify_show_line() {
    local mark="$1" path="$2" size="?" linked
    linked="$(term_path_link "${path}")"
    if [[ "${LINUXBKUP_INSPECT_QUICK:-0}" -eq 1 ]]; then
      printf '    %s %s\n' "${mark}" "${linked}"
    else
      size="$(fs_du_sh "${path}" | awk '{print $1}')"
      printf '    %s %6s  %s\n' "${mark}" "${size:-?}" "${linked}"
    fi
  }

  printf '  Potentially regeneratable:\n'
  rows=()
  while IFS= read -r p; do
    [[ -z "${p}" ]] && continue
    rows+=("$(_classify_show_line '~' "${p}")")
    regen_hits=$((regen_hits + 1))
  done < <(constraints_build_paths "${home}" CONSTRAINTS_REGENERABLE_TARGETS)

  if [[ "${#rows[@]}" -eq 0 ]]; then
    ui_item note "none spotted in quick scan"
  else
    printf '%s\n' "${rows[@]}" | constraints_list_apply
    constraints_list_footer "regeneratable"
    log_info "Cross-check Large items; node_modules/.venv/target often regeneratable."
  fi

  printf '  Potentially important user / app data:\n'
  rows=()
  while IFS= read -r p; do
    [[ -z "${p}" ]] && continue
    rows+=("$(_classify_show_line '!' "${p}")")
    important_hits=$((important_hits + 1))
  done < <(constraints_build_paths "${home}" CONSTRAINTS_IMPORTANT_TARGETS)

  if [[ "${#rows[@]}" -eq 0 ]]; then
    ui_item note "none in quick scan"
  else
    printf '%s\n' "${rows[@]}" | constraints_list_apply
    constraints_list_footer "important paths"
  fi

  printf '  Sensitive paths detected (contents NOT shown):\n'
  rows=()
  while IFS= read -r p; do
    [[ -z "${p}" ]] && continue
    rows+=("    ✓ $(term_path_link "${p}")")
    sens=$((sens + 1))
  done < <(constraints_build_paths "${home}" CONSTRAINTS_SECRETS_TARGETS)

  if [[ -d "${home}" && "${LINUXBKUP_NO_DEFAULTS:-0}" -eq 0 ]]; then
    local find_expr=() name
    for name in "${CONSTRAINTS_SECRETS_FIND_NAMES[@]+"${CONSTRAINTS_SECRETS_FIND_NAMES[@]}"}"; do
      [[ "${#find_expr[@]}" -gt 0 ]] && find_expr+=(-o)
      find_expr+=(-name "${name}")
    done
    if [[ "${#find_expr[@]}" -gt 0 ]]; then
      while IFS= read -r path; do
        [[ -z "${path}" ]] && continue
        if constraints_matches_any_regex "${path}" LINUXBKUP_EXCLUDE_REGEXES; then
          continue
        fi
        rows+=("    ✓ $(term_path_link "${path}")")
        sens=$((sens + 1))
      done < <(find "${home}" -maxdepth 2 \( "${find_expr[@]}" \) 2>/dev/null | head -n 20)
    fi
  fi

  if [[ "${#rows[@]}" -eq 0 ]]; then
    ui_item note "none in quick scan"
  else
    printf '%s\n' "${rows[@]}" | constraints_list_apply
    constraints_list_footer "sensitive paths"
    log_info "Sensitive paths use age passphrase encryption in backup (Phase 3)."
  fi
}
