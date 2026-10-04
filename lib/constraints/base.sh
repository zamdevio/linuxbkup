# shellcheck shell=bash
# Central path-list merge: defaults + --include/--exclude (regex) + --no-defaults.
# Exclude always wins. Include adds path templates and/or keeps regex matches.

# shellcheck source=lib/constraints/list.sh
source "${LINUXBKUP_ROOT}/lib/constraints/list.sh"
# shellcheck source=lib/constraints/size_targets.sh
source "${LINUXBKUP_ROOT}/lib/constraints/size_targets.sh"
# shellcheck source=lib/constraints/regenerable.sh
source "${LINUXBKUP_ROOT}/lib/constraints/regenerable.sh"
# shellcheck source=lib/constraints/important.sh
source "${LINUXBKUP_ROOT}/lib/constraints/important.sh"
# shellcheck source=lib/constraints/secrets.sh
source "${LINUXBKUP_ROOT}/lib/constraints/secrets.sh"

constraints_expand_template() {
  local home="$1" template="$2"
  local out="${template//\{home\}/${home}}"
  if [[ "${out}" == /* ]]; then
    printf '%s\n' "${out}"
  else
    printf '%s/%s\n' "${home%/}" "${out}"
  fi
}

constraints_matches_any_regex() {
  local path="$1"
  local -n _rx="$2"
  local re
  [[ "${#_rx[@]}" -eq 0 ]] && return 1
  for re in "${_rx[@]}"; do
    [[ -z "${re}" ]] && continue
    if [[ "${path}" =~ ${re} ]]; then
      return 0
    fi
  done
  return 1
}

# Build filtered paths from a named template array.
# Args: home  NAME_of_templates_array
constraints_build_paths() {
  local home="$1"
  local -n _templates="$2"
  local existing_only="${LINUXBKUP_CONSTRAINTS_EXISTING_ONLY:-1}"
  local t path inc
  local -a candidates=()

  if [[ "${LINUXBKUP_NO_DEFAULTS:-0}" -eq 0 ]]; then
    for t in "${_templates[@]+"${_templates[@]}"}"; do
      [[ -z "${t}" ]] && continue
      candidates+=("$(constraints_expand_template "${home}" "${t}")")
    done
  fi

  # User includes: path-like templates are expanded into the candidate set.
  for inc in "${LINUXBKUP_INCLUDE_REGEXES[@]+"${LINUXBKUP_INCLUDE_REGEXES[@]}"}"; do
    [[ -z "${inc}" ]] && continue
    # Path-like (absolute, relative, {home}, or simple name without regex metachar intent)
    if [[ "${inc}" == /* || "${inc}" == \{home\}/* || "${inc}" == .*/* || "${inc}" == ./* || "${inc}" != *[\|\(\)\[\]\*\+\?\^\$]* ]]; then
      candidates+=("$(constraints_expand_template "${home}" "${inc}")")
    fi
  done

  local -A seen=()
  for path in "${candidates[@]+"${candidates[@]}"}"; do
    [[ -z "${path}" ]] && continue
    [[ -n "${seen[${path}]+x}" ]] && continue
    seen["${path}"]=1

    # Exclude always wins
    if constraints_matches_any_regex "${path}" LINUXBKUP_EXCLUDE_REGEXES; then
      log_debug "exclude hit: ${path}"
      continue
    fi

    # When includes contain regex metacharacters, also allow keep-if-match on candidates
    # (already in set). When --no-defaults and only regex includes, candidates may be empty —
    # user should pass path-like includes.
    if [[ "${LINUXBKUP_NO_DEFAULTS:-0}" -eq 1 && "${#LINUXBKUP_INCLUDE_REGEXES[@]}" -gt 0 ]]; then
      local ok=0
      for inc in "${LINUXBKUP_INCLUDE_REGEXES[@]}"; do
        local expanded
        expanded="$(constraints_expand_template "${home}" "${inc}")"
        if [[ "${path}" == "${expanded}" || "${path}" =~ ${inc} ]]; then
          ok=1
          break
        fi
      done
      [[ "${ok}" -eq 1 ]] || continue
    fi

    if [[ "${existing_only}" -eq 1 && ! -e "${path}" ]]; then
      continue
    fi
    printf '%s\n' "${path}"
  done
}

constraints_is_regenerable_path() {
  constraints_matches_any_regex "$1" CONSTRAINTS_REGENERABLE_REGEXES
}

constraints_is_secret_path() {
  constraints_matches_any_regex "$1" CONSTRAINTS_SECRETS_REGEXES
}
