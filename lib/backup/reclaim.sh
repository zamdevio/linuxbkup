# shellcheck shell=bash
# Reclaim regenerable skips back into the backup include set.
# Pass array *names* as strings — never nest namerefs with the same local name.

# Collect reclaim candidates from classify scan rows.
# Args: scan_array_name out_array_name
backup_reclaim_candidates() {
  local __scan="$1" __out="$2"
  local row p class action size reason bytes human line
  local -a __rows=()
  eval "${__out}=()"
  eval "__rows=(\"\${${__scan}[@]+\"\${${__scan}[@]}\"}\")"
  for row in "${__rows[@]+"${__rows[@]}"}"; do
    [[ -z "${row}" ]] && continue
    IFS=$'\t' read -r p class action size reason <<<"${row}" || true
    [[ "${class}" == "skip" && "${action}" == "skip" ]] || continue
    IFS=$'\t' read -r bytes human <<<"$(backup_resolve_size "${p}" "${size}")" || true
    printf -v line '%s\t%s\t%s\t%s' "${p}" "${human}" "regenerable" "skip"
    eval "${__out}+=(\"\${line}\")"
  done
}

# Apply --reclaim / --reclaim-all / --ask reclaim step into include_set.
# Args: scan_array_name include_assoc_name
# Fills BACKUP_RECLAIMED. Returns 1 if user aborts.
backup_apply_reclaim() {
  local __scan="$1" __include="$2"
  local -a candidates=() picked=()
  local path row

  backup_reclaim_candidates "${__scan}" candidates
  [[ "${#candidates[@]}" -gt 0 ]] || {
    log_verbose "reclaim: no regenerable skips found"
    return 0
  }

  if [[ "${LINUXBKUP_RECLAIM_ALL:-0}" -eq 1 ]]; then
    log_warn "reclaim-all: including ${#candidates[@]} regenerable path(s) (can be huge)"
    for row in "${candidates[@]}"; do
      path="${row%%$'\t'*}"
      eval "${__include}[\"\${path}\"]=1"
      BACKUP_RECLAIMED["${path}"]=1
    done
    return 0
  fi

  if [[ "${LINUXBKUP_RECLAIM:-0}" -eq 1 || "${LINUXBKUP_ASK:-0}" -eq 1 ]]; then
    if ! ask_select_backup_paths candidates picked \
      "Reclaim regenerables  (suggested: skip — pick to include)"; then
      return 1
    fi
    for path in "${picked[@]+"${picked[@]}"}"; do
      eval "${__include}[\"\${path}\"]=1"
      BACKUP_RECLAIMED["${path}"]=1
    done
    log_ok "reclaimed ${#picked[@]} regenerable path(s)"
  fi
  return 0
}
