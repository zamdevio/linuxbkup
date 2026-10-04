# shellcheck shell=bash
# Shallow $HOME scan + classification. Filter stack for sizes.
# Emits TSV rows: path<TAB>class<TAB>action<TAB>size<TAB>reason

# shellcheck source=lib/constraints/rules.sh
source "${LINUXBKUP_ROOT}/lib/constraints/rules.sh"

# Decide action for unexpected paths.
# --yes or non-TTY → include; interactive TTY → ask (backup confirms).
classify_unexpected_action() {
  # --ask always defers to interactive decide step
  if [[ "${LINUXBKUP_ASK:-0}" -eq 1 ]]; then
    printf '%s\n' "ask"
    return 0
  fi
  if [[ "${LINUXBKUP_YES:-0}" -eq 1 ]]; then
    printf '%s\n' "include"
    return 0
  fi
  if [[ ! -t 0 ]]; then
    printf '%s\n' "include"
    return 0
  fi
  printf '%s\n' "ask"
}

classify_basename_in_list() {
  local needle="$1"
  shift
  local x
  for x in "$@"; do
    [[ "${x}" == "${needle}" ]] && return 0
  done
  return 1
}

_classify_size() {
  local path="$1" mode="${2:-filtered}"
  if [[ "${LINUXBKUP_INSPECT_QUICK:-0}" -eq 1 ]]; then
    printf '%s\n' "?"
    return 0
  fi
  if declare -F fs_du_sh >/dev/null 2>&1; then
    fs_du_sh "${path}" "${mode}" 2>/dev/null | awk -F'\t' '{print $1}'
  else
    printf '%s\n' "?"
  fi
}

# Classify a single path. Prints one TSV row when applicable.
# Args: path home
classify_one_path() {
  local path="$1" home="$2"
  local base rel size="?" class action reason
  local inc expanded child

  [[ -e "${path}" ]] || return 0
  if constraints_path_excluded "${path}"; then
    return 0
  fi

  base="$(basename "${path}")"
  rel="${path#"${home}"/}"
  [[ "${path}" == "${home}" ]] && return 0

  # Absolute /etc snippets
  if [[ "${path}" == /etc/* ]]; then
    printf '%s\t%s\t%s\t%s\t%s\n' "${path}" "include" "include" \
      "$(_classify_size "${path}" filtered)" "optional system snippet"
    return 0
  fi

  # User --include path-like / regex forces include
  for inc in "${LINUXBKUP_INCLUDE_REGEXES[@]+"${LINUXBKUP_INCLUDE_REGEXES[@]}"}"; do
    [[ -z "${inc}" ]] && continue
    expanded="$(constraints_expand_template "${home}" "${inc}")"
    if [[ "${path}" == "${expanded}" || "${path}" =~ ${inc} ]]; then
      printf '%s\t%s\t%s\t%s\t%s\n' "${path}" "include" "include" \
        "$(_classify_size "${path}" filtered)" "user --include"
      return 0
    fi
  done

  # Secrets
  if constraints_is_secret_path "${path}" \
    || [[ "${base}" == ".ssh" || "${base}" == ".gnupg" || "${base}" == ".aws" ]]; then
    if [[ "${LINUXBKUP_NO_SECRETS:-0}" -eq 1 ]]; then
      printf '%s\t%s\t%s\t%s\t%s\n' "${path}" "secret" "skip" \
        "$(_classify_size "${path}" filtered)" "secret (--no-secrets)"
    else
      printf '%s\t%s\t%s\t%s\t%s\n' "${path}" "secret" "include" \
        "$(_classify_size "${path}" filtered)" "auto-secret"
    fi
    return 0
  fi

  # Regenerable / skip list
  if constraints_is_regenerable_path "${path}" \
    || classify_basename_in_list "${base}" "${CONSTRAINTS_RULE_SKIP_BASENAMES[@]+"${CONSTRAINTS_RULE_SKIP_BASENAMES[@]}"}"; then
    printf '%s\t%s\t%s\t%s\t%s\n' "${path}" "skip" "skip" \
      "$(_classify_size "${path}" raw)" "regenerable"
    return 0
  fi

  if classify_basename_in_list "${base}" "${CONSTRAINTS_RULE_INCLUDE_FILES[@]+"${CONSTRAINTS_RULE_INCLUDE_FILES[@]}"}"; then
    printf '%s\t%s\t%s\t%s\t%s\n' "${path}" "include" "include" \
      "$(_classify_size "${path}" filtered)" "known dotfile"
    return 0
  fi

  if classify_basename_in_list "${base}" "${CONSTRAINTS_RULE_INCLUDE_DIRS[@]+"${CONSTRAINTS_RULE_INCLUDE_DIRS[@]}"}"; then
    printf '%s\t%s\t%s\t%s\t%s\n' "${path}" "include" "include" \
      "$(_classify_size "${path}" filtered)" "known config dir"
    return 0
  fi

  # ~/.local itself — children handled separately
  if [[ "${rel}" == ".local" ]]; then
    return 0
  fi

  # ~/.local/<child>
  if [[ "${rel}" == .local/* ]]; then
    child="${rel#.local/}"
    child="${child%%/*}"
    if classify_basename_in_list "${child}" "${CONSTRAINTS_RULE_LOCAL_INCLUDE[@]+"${CONSTRAINTS_RULE_LOCAL_INCLUDE[@]}"}"; then
      printf '%s\t%s\t%s\t%s\t%s\n' "${path}" "include" "include" \
        "$(_classify_size "${path}" filtered)" "known .local/${child}"
    elif constraints_is_regenerable_path "${path}"; then
      printf '%s\t%s\t%s\t%s\t%s\n' "${path}" "skip" "skip" \
        "$(_classify_size "${path}" raw)" "regenerable under .local"
    else
      printf '%s\t%s\t%s\t%s\t%s\n' "${path}" "unexpected" "$(classify_unexpected_action)" \
        "$(_classify_size "${path}" filtered)" "unknown under .local"
    fi
    return 0
  fi

  # Top-level unknown → unexpected
  printf '%s\t%s\t%s\t%s\t%s\n' "${path}" "unexpected" "$(classify_unexpected_action)" \
    "$(_classify_size "${path}" filtered)" "unknown home entry"
}

# Scan home: top-level entries + ~/.local/* + optional /etc snippets.
classify_scan_home() {
  local home="$1"
  local p child inc expanded

  [[ -d "${home}" ]] || return 0

  if [[ "${LINUXBKUP_NO_DEFAULTS:-0}" -eq 1 ]]; then
    for inc in "${LINUXBKUP_INCLUDE_REGEXES[@]+"${LINUXBKUP_INCLUDE_REGEXES[@]}"}"; do
      expanded="$(constraints_expand_template "${home}" "${inc}")"
      [[ -e "${expanded}" ]] || continue
      classify_one_path "${expanded}" "${home}"
    done
    return 0
  fi

  while IFS= read -r -d '' p; do
    [[ "$(basename "${p}")" == ".local" && -d "${p}" ]] && continue
    classify_one_path "${p}" "${home}"
  done < <(find "${home}" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)

  if [[ -d "${home}/.local" ]]; then
    while IFS= read -r -d '' child; do
      classify_one_path "${child}" "${home}"
    done < <(find "${home}/.local" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)
  fi

  for p in "${CONSTRAINTS_RULE_ETC[@]+"${CONSTRAINTS_RULE_ETC[@]}"}"; do
    [[ -e "${p}" ]] || continue
    classify_one_path "${p}" "${home}"
  done
}

# Paths with action include (and ask when LINUXBKUP_CLASSIFY_INCLUDE_ASK=1).
classify_plan_include_paths() {
  local home="$1"
  local path class action size reason
  while IFS=$'\t' read -r path class action size reason; do
    [[ -z "${path:-}" ]] && continue
    case "${action}" in
      include) printf '%s\n' "${path}" ;;
      ask)
        if [[ "${LINUXBKUP_CLASSIFY_INCLUDE_ASK:-0}" -eq 1 ]]; then
          printf '%s\n' "${path}"
        fi
        ;;
    esac
  done < <(classify_scan_home "${home}")
}
