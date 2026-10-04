# shellcheck shell=bash
# Reclaim regenerable skips back into the backup include set.

# Collect reclaim candidates from classify scan rows.
# Input nameref: rows path\tclass\taction\tsize\treason
# Output nameref: decide rows path\thuman\tclass\tsuggested
backup_reclaim_candidates() {
  local -n _scan="$1"
  local -n _out="$2"
  local row p class action size reason bytes human
  _out=()
  for row in "${_scan[@]+"${_scan[@]}"}"; do
    [[ -z "${row}" ]] && continue
    IFS=$'\t' read -r p class action size reason <<<"${row}" || true
    [[ "${class}" == "skip" && "${action}" == "skip" ]] || continue
    IFS=$'\t' read -r bytes human <<<"$(backup_resolve_size "${p}" "${size}")" || true
    _out+=("$(printf '%s\t%s\t%s\t%s' "${p}" "${human}" "regenerable" "skip")")
  done
}

# Apply --reclaim / --reclaim-all / --ask reclaim step into include_set.
# Also fills BACKUP_RECLAIMED associative array (path→1).
# Returns 1 if user aborts.
backup_apply_reclaim() {
  local -n _scan="$1"
  local -n _include="$2"
  local -a candidates=() picked=()
  local path row

  backup_reclaim_candidates _scan candidates
  [[ "${#candidates[@]}" -gt 0 ]] || {
    log_verbose "reclaim: no regenerable skips found"
    return 0
  }

  if [[ "${LINUXBKUP_RECLAIM_ALL:-0}" -eq 1 ]]; then
    log_warn "reclaim-all: including ${#candidates[@]} regenerable path(s) (can be huge)"
    for row in "${candidates[@]}"; do
      path="${row%%$'\t'*}"
      _include["${path}"]=1
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
      _include["${path}"]=1
      BACKUP_RECLAIMED["${path}"]=1
    done
    log_ok "reclaimed ${#picked[@]} regenerable path(s)"
  fi
  return 0
}
