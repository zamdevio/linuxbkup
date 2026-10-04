# shellcheck shell=bash
# Backup staging directory lifecycle.

backup_stage_create() {
  local base="${TMPDIR:-/tmp}/wslbkup.$$.$RANDOM"
  mkdir -p "${base}"/{metadata,packages,services,config,home,secrets}
  printf '%s\n' "${base}"
}

backup_stage_cleanup() {
  local stage="${1:-}"
  [[ -n "${stage}" && -d "${stage}" ]] || return 0
  case "${stage}" in
    /tmp/wslbkup.*|"${TMPDIR:-/tmp}"/wslbkup.*)
      rm -rf "${stage}"
      log_debug "staging removed: ${stage}"
      ;;
    *)
      log_warn "refusing to remove unexpected staging path: ${stage}"
      ;;
  esac
}

backup_write_metadata() {
  local stage="$1" user="$2" home="$3"
  local meta="${stage}/metadata"

  if [[ "${WSLBKUP_DRY_RUN:-0}" -eq 1 ]]; then
    log_info "dry-run — would write metadata for ${user}"
    return 0
  fi

  mkdir -p "${meta}"
  {
    printf 'version=%s\n' "${WSLBKUP_VERSION}"
    printf 'created=%s\n' "$(date -Iseconds)"
    printf 'user=%s\n' "${user}"
    printf 'home=%s\n' "${home}"
    printf 'hostname=%s\n' "$(hostname 2>/dev/null || echo unknown)"
  } >"${meta}/backup.env"

  # shellcheck source=lib/env/distro.sh
  source "${WSLBKUP_ROOT}/lib/env/distro.sh"
  {
    printf 'pretty=%s\n' "$(env_distro_pretty)"
    printf 'id=%s\n' "$(env_distro_id)"
    printf 'version_id=%s\n' "$(env_distro_version_id)"
    printf 'arch=%s\n' "$(env_arch)"
    printf 'wsl=%s\n' "$(env_wsl_kind)"
    printf 'wsl_name=%s\n' "$(env_wsl_distro_name)"
  } >"${meta}/distro.env"

  printf '%s\n' "${user}" >"${meta}/users"
  log_ok "metadata written"
}

# INDEX — do NOT sort the entire tree (that stalls on large homes).
backup_write_index() {
  local stage="$1"
  local index="${stage}/INDEX"

  if [[ "${WSLBKUP_DRY_RUN:-0}" -eq 1 ]]; then
    return 0
  fi

  log_info "writing INDEX…"
  {
    printf 'wslbkup backup index\n'
    printf 'version=%s\n' "${WSLBKUP_VERSION}"
    printf 'created=%s\n' "$(date -Iseconds)"
    printf '\ncontents (first 500 paths, unsorted sample):\n'
    find "${stage}" -mindepth 1 -printf '%P\n' 2>/dev/null | head -n 500
  } >"${index}"
  log_ok "INDEX written"
}
