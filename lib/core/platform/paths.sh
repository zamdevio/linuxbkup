# shellcheck shell=bash
# Default archive destinations and staging roots.

# shellcheck source=lib/core/platform/detect.sh
source "${LINUXBKUP_ROOT}/lib/core/platform/detect.sh"
# shellcheck source=lib/core/platform/windows.sh
source "${LINUXBKUP_ROOT}/lib/core/platform/windows.sh"

# Native Linux default (no Windows mount required).
platform_native_backup_dir() {
  printf '%s\n' "${HOME}/Backups/linuxbkup"
}

# Preferred default backup directory:
# - Windows Downloads/linuxbkup when a mount resolves
# - else ~/Backups/linuxbkup
platform_default_backup_dir() {
  local dir
  if dir="$(windows_downloads_backup_dir)"; then
    printf '%s\n' "${dir}"
    return 0
  fi
  platform_native_backup_dir
}

# Suggested archive filename: <distro>-<timestamp>.tar.zst
platform_default_archive_name() {
  local distro ts
  # Prefer WSL distro name when present; else os-release id; else hostname.
  distro="${WSL_DISTRO_NAME:-}"
  if [[ -z "${distro}" || "${distro}" == "unknown" ]]; then
    if [[ -r /etc/os-release ]]; then
      # shellcheck disable=SC1091
      . /etc/os-release
      distro="${ID:-}"
    fi
  fi
  [[ -n "${distro}" ]] || distro="$(hostname -s 2>/dev/null || printf 'linux')"
  distro="$(printf '%s' "${distro}" | tr -c 'A-Za-z0-9._-' '_' )"
  ts="$(date +%Y%m%d-%H%M%S)"
  printf '%s-%s.tar.zst\n' "${distro}" "${ts}"
}

# Full default archive path (dir + name). Always succeeds.
platform_default_archive_path() {
  printf '%s/%s\n' "$(platform_default_backup_dir)" "$(platform_default_archive_name)"
}

# Staging directory prefix under TMPDIR (caller appends unique suffix).
platform_staging_prefix() {
  printf '%s/linuxbkup\n' "${TMPDIR:-/tmp}"
}

# Inspect / plan UI for default destination.
platform_print_backup_destination() {
  local dir name full kind
  kind="$(platform_kind)"
  ui_section "Backup destination (default)"
  if [[ -n "${LINUXBKUP_OUTPUT:-}" ]]; then
    ui_kv "Override" "${LINUXBKUP_OUTPUT}"
    return 0
  fi

  dir="$(platform_default_backup_dir)"
  name="$(platform_default_archive_name)"
  full="${dir}/${name}"
  ui_kv "Platform" "${kind}"
  ui_kv_path "Directory" "${dir}"
  ui_kv_path "Example" "${full}"

  if [[ -d "${dir}" ]]; then
    if [[ -w "${dir}" ]]; then
      log_ok "default destination writable"
    else
      log_warn "default destination exists but may not be writable"
    fi
  elif [[ -d "$(dirname "${dir}")" ]]; then
    log_info "directory will be created on first backup"
  else
    log_info "parent will be created on first backup (or pass --output)"
  fi
}
