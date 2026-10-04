# shellcheck shell=bash
# Shared filter stack: regenerable defaults + user --exclude for sizing / scans.
# Exclude always wins. Callers source base.sh (or regenerable) first.

# Append GNU du --exclude=ARG words into named array.
# Also maps simple user --exclude values that look like basenames/globs (no ERE metachars).
constraints_du_exclude_args() {
  local -n _out="$1"
  local g re
  for g in "${CONSTRAINTS_DU_EXCLUDE_GLOBS[@]+"${CONSTRAINTS_DU_EXCLUDE_GLOBS[@]}"}"; do
    [[ -z "${g}" ]] && continue
    _out+=(--exclude="${g}")
  done
  for re in "${LINUXBKUP_EXCLUDE_REGEXES[@]+"${LINUXBKUP_EXCLUDE_REGEXES[@]}"}"; do
    [[ -z "${re}" ]] && continue
    # Basename-like or simple glob only — skip full EREs
    if [[ "${re}" != *[\|\(\)\[\]\+\?\^\$]* ]]; then
      # strip leading ./ or /
      g="${re#./}"
      g="${g#/}"
      g="${g%/}"
      [[ -n "${g}" ]] && _out+=(--exclude="${g}")
    fi
  done
}

# True if path should be omitted from listings (user --exclude hit).
constraints_path_excluded() {
  constraints_matches_any_regex "$1" LINUXBKUP_EXCLUDE_REGEXES
}
