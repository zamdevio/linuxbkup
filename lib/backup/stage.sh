# shellcheck shell=bash
# Backup staging directory lifecycle.

# shellcheck source=lib/core/compat/compat.sh
[[ -n "${LINUXBKUP_ROOT:-}" ]] && source "${LINUXBKUP_ROOT}/lib/core/compat/compat.sh"

backup_stage_create() {
  local base parent
  if [[ -n "${LINUXBKUP_STAGE_DIR:-}" ]]; then
    parent="${LINUXBKUP_STAGE_DIR}"
    mkdir -p "${parent}" || {
      log_fatal "cannot create --stage-dir: ${parent}"
      return 1
    }
  fi
  base="$(compat_stage_path backup)"
  mkdir -p "${base}"/{metadata,packages,services,config,home,secrets} || {
    log_fatal "cannot create staging: ${base}"
    return 1
  }
  printf '%s\n' "${base}"
}

# True if path looks like a linuxbkup staging dir we may remove.
backup_stage_is_ours() {
  local stage="$1"
  if declare -F compat_stage_is_ours >/dev/null 2>&1; then
    compat_stage_is_ours "${stage}"
    return $?
  fi
  case "${stage}" in
    /tmp/linuxbkup*|"${TMPDIR:-/tmp}"/linuxbkup*) return 0 ;;
  esac
  if [[ -n "${LINUXBKUP_STAGE_DIR:-}" ]]; then
    case "${stage}" in
      "${LINUXBKUP_STAGE_DIR%/}"/linuxbkup*) return 0 ;;
    esac
  fi
  return 1
}

backup_stage_cleanup() {
  local stage="${1:-}"
  [[ -n "${stage}" && -d "${stage}" ]] || return 0

  if [[ "${LINUXBKUP_KEEP_STAGE:-0}" -eq 1 ]]; then
    log_info "keeping staging (--keep-stage): ${stage}"
    if declare -F compat_print_stage_path >/dev/null 2>&1; then
      compat_print_stage_path "Stage" "${stage}"
    elif declare -F ui_kv_path >/dev/null 2>&1; then
      ui_kv_path "Stage" "${stage}"
    fi
    return 0
  fi

  if backup_stage_is_ours "${stage}"; then
    rm -rf "${stage}"
    log_debug "staging removed: ${stage}"
  else
    log_warn "refusing to remove unexpected staging path: ${stage}"
  fi
}

backup_write_metadata() {
  local stage="$1" user="$2" home="$3"
  local meta="${stage}/metadata"

  if [[ "${LINUXBKUP_DRY_RUN:-0}" -eq 1 ]]; then
    log_info "dry-run — would write metadata for ${user}"
    return 0
  fi

  mkdir -p "${meta}"
  {
    printf 'version=%s\n' "${LINUXBKUP_VERSION}"
    printf 'created=%s\n' "$(date -Iseconds)"
    printf 'user=%s\n' "${user}"
    printf 'home=%s\n' "${home}"
    printf 'hostname=%s\n' "$(hostname 2>/dev/null || echo unknown)"
    printf 'profile=%s\n' "${LINUXBKUP_PROFILE:-balanced}"
  } >"${meta}/backup.env"

  # shellcheck source=lib/env/distro.sh
  source "${LINUXBKUP_ROOT}/lib/env/distro.sh"
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

  if [[ "${LINUXBKUP_DRY_RUN:-0}" -eq 1 ]]; then
    return 0
  fi

  log_info "writing INDEX…"
  # Avoid find|head SIGPIPE under set -o pipefail (exits the whole backup).
  {
    printf 'linuxbkup index\n'
    printf 'version=%s\n' "${LINUXBKUP_VERSION}"
    printf 'created=%s\n' "$(date -Iseconds)"
    printf '\ncontents (first 500 paths, unsorted sample):\n'
    find "${stage}" -mindepth 1 -printf '%P\n' 2>/dev/null | head -n 500 || true
  } >"${index}" || {
    log_fatal "failed to write INDEX at ${index}"
    return 1
  }
  log_ok "INDEX written"
}
