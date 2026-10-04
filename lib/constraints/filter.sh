# shellcheck shell=bash
# Shared filter stack: regenerable defaults + user --exclude for sizing / scans.
# Exclude always wins. Callers source base.sh (or regenerable) first.

# Normalize a user --exclude / --include token for path matching.
# Expands ~ and {home} against LINUXBKUP_HOME (or $HOME); strips trailing /.
constraints_normalize_user_path() {
  local token="$1"
  local home="${LINUXBKUP_HOME:-${HOME:-}}"
  local out

  [[ -n "${token}" ]] || return 1
  out="${token}"
  if [[ -n "${home}" ]]; then
    out="${out//\{home\}/${home}}"
    if [[ "${out}" == "~" ]]; then
      out="${home}"
    elif [[ "${out}" == "~/"* ]]; then
      out="${home}/${out:2}"
    fi
  fi
  # Collapse trailing slashes (except root)
  while [[ "${#out}" -gt 1 && "${out}" == */ ]]; do
    out="${out%/}"
  done
  printf '%s\n' "${out}"
}

# True if path matches one user exclude pattern (path-like or ERE).
# Path-like: exact, prefix (dir), basename under LINUXBKUP_HOME, or relative to home.
# Patterns with clear ERE metacharacters also try bash =~ as fallback.
constraints_exclude_matches() {
  local path="$1" pattern="$2"
  local home="${LINUXBKUP_HOME:-${HOME:-}}"
  local norm_path norm_pat base rel

  [[ -n "${path}" && -n "${pattern}" ]] || return 1
  norm_path="$(constraints_normalize_user_path "${path}")"
  norm_pat="$(constraints_normalize_user_path "${pattern}")"

  # Exact or directory prefix
  if [[ "${norm_path}" == "${norm_pat}" || "${norm_path}" == "${norm_pat}/"* ]]; then
    return 0
  fi

  # Simple basename (no /): match top-level under active home, or final component
  if [[ "${norm_pat}" != */* ]]; then
    base="$(basename -- "${norm_path}")"
    if [[ "${base}" == "${norm_pat}" ]]; then
      return 0
    fi
    if [[ -n "${home}" && "${norm_path}" == "${home}/${norm_pat}" ]]; then
      return 0
    fi
  fi

  # Relative path under home (e.g. .local/share)
  if [[ -n "${home}" && "${norm_pat}" != /* ]]; then
    if [[ "${norm_path}" == "${home}/${norm_pat}" || "${norm_path}" == "${home}/${norm_pat}/"* ]]; then
      return 0
    fi
  fi

  # Intentional ERE (metacharacters) — last resort; path-like dots are NOT wildcards above
  if [[ "${pattern}" == *[\|\(\)\[\]\+\?\^\$]* || "${pattern}" == *'.*'* ]]; then
    [[ "${path}" =~ ${pattern} ]] && return 0
  fi
  return 1
}

# Append GNU du --exclude=ARG words into named array.
# Also maps simple user --exclude values that look like basenames/globs (no ERE metachars).
constraints_du_exclude_args() {
  local -n _out="$1"
  local g re norm
  for g in "${CONSTRAINTS_DU_EXCLUDE_GLOBS[@]+"${CONSTRAINTS_DU_EXCLUDE_GLOBS[@]}"}"; do
    [[ -z "${g}" ]] && continue
    _out+=(--exclude="${g}")
  done
  for g in "${CONSTRAINTS_FILE_EXCLUDE_GLOBS[@]+"${CONSTRAINTS_FILE_EXCLUDE_GLOBS[@]}"}"; do
    [[ -z "${g}" ]] && continue
    _out+=(--exclude="${g}")
  done
  for re in "${LINUXBKUP_EXCLUDE_REGEXES[@]+"${LINUXBKUP_EXCLUDE_REGEXES[@]}"}"; do
    [[ -z "${re}" ]] && continue
    # Basename-like or simple path — skip full EREs
    if [[ "${re}" != *[\|\(\)\[\]\+\?\^\$]* ]]; then
      norm="$(constraints_normalize_user_path "${re}")"
      g="$(basename -- "${norm}")"
      [[ -n "${g}" && "${g}" != "/" ]] && _out+=(--exclude="${g}")
    fi
  done
}

# True if path should be omitted from listings / classify (user --exclude hit).
constraints_path_excluded() {
  local path="$1" re
  for re in "${LINUXBKUP_EXCLUDE_REGEXES[@]+"${LINUXBKUP_EXCLUDE_REGEXES[@]}"}"; do
    [[ -z "${re}" ]] && continue
    if constraints_exclude_matches "${path}" "${re}"; then
      return 0
    fi
  done
  return 1
}
