# shellcheck shell=bash
# Listing policy: default top-N, --full, or --top <n>.

# Default page size for tables/lists unless a caller overrides.
CONSTRAINTS_LIST_DEFAULT_TOP="${CONSTRAINTS_LIST_DEFAULT_TOP:-10}"

# Resolve effective limit for a list.
# Args: [caller_default]
# Prints: "full" | a positive integer
constraints_list_limit() {
  local caller_default="${1:-${CONSTRAINTS_LIST_DEFAULT_TOP}}"
  if [[ "${LINUXBKUP_LIST_FULL:-0}" -eq 1 ]]; then
    printf '%s\n' "full"
    return 0
  fi
  if [[ -n "${LINUXBKUP_LIST_TOP:-}" ]]; then
    printf '%s\n' "${LINUXBKUP_LIST_TOP}"
    return 0
  fi
  printf '%s\n' "${caller_default}"
}

# Filter stdin lines through the listing policy.
# Args: [caller_default_top]
# Sets CONSTRAINTS_LIST_TOTAL / CONSTRAINTS_LIST_SHOWN in the caller via nameref-ish globals.
constraints_list_apply() {
  local caller_default="${1:-${CONSTRAINTS_LIST_DEFAULT_TOP}}"
  local limit line count=0 shown=0
  local -a buf=()

  limit="$(constraints_list_limit "${caller_default}")"

  while IFS= read -r line || [[ -n "${line}" ]]; do
    [[ -z "${line}" && count -eq 0 && shown -eq 0 ]] && continue
    buf+=("${line}")
    count=$((count + 1))
  done

  CONSTRAINTS_LIST_TOTAL="${count}"

  if [[ "${limit}" == "full" ]]; then
    printf '%s\n' "${buf[@]+"${buf[@]}"}"
    CONSTRAINTS_LIST_SHOWN="${count}"
    return 0
  fi

  local n="${limit}"
  [[ "${n}" =~ ^[0-9]+$ ]] || n="${CONSTRAINTS_LIST_DEFAULT_TOP}"
  [[ "${n}" -lt 1 ]] && n=1

  local i
  for ((i = 0; i < count && i < n; i++)); do
    printf '%s\n' "${buf[i]}"
    shown=$((shown + 1))
  done
  CONSTRAINTS_LIST_SHOWN="${shown}"

  if [[ "${count}" -gt "${shown}" ]]; then
    log_info "Showing ${shown}/${count} — pass -F/--full or -T/--top <n> for more"
  fi
}

constraints_list_footer() {
  local label="${1:-items}"
  if [[ "${CONSTRAINTS_LIST_TOTAL:-0}" -gt "${CONSTRAINTS_LIST_SHOWN:-0}" ]]; then
    ui_item note "${CONSTRAINTS_LIST_SHOWN}/${CONSTRAINTS_LIST_TOTAL} ${label} shown"
  fi
}
