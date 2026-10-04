# shellcheck shell=bash
# Resolve Windows paths visible from WSL (default backup destination).

# Convert Windows path like C:\Users\foo to /mnt/c/Users/foo
windows_to_wsl_path() {
  local win="$1"
  win="${win//$'\r'/}"
  win="${win%"${win##*[![:space:]]}"}" # rtrim
  win="${win#"${win%%[![:space:]]*}"}" # ltrim
  [[ -n "${win}" ]] || return 1

  # Already a WSL path?
  if [[ "${win}" == /mnt/* || "${win}" == /home/* ]]; then
    printf '%s\n' "${win}"
    return 0
  fi

  local drive rest
  if [[ "${win}" =~ ^([A-Za-z]):[\\/](.*)$ ]]; then
    drive="$(printf '%s' "${BASH_REMATCH[1]}" | tr '[:upper:]' '[:lower:]')"
    rest="${BASH_REMATCH[2]//\\//}"
    printf '/mnt/%s/%s\n' "${drive}" "${rest}"
    return 0
  fi
  return 1
}

windows_userprofile_win() {
  local out=""
  if wslbkup_require_cmd cmd.exe; then
    out="$(cmd.exe /c "echo %USERPROFILE%" 2>/dev/null | tr -d '\r' | tail -n1 || true)"
    out="${out%"${out##*[![:space:]]}"}"
    if [[ -n "${out}" && "${out}" != *"%USERPROFILE%"* ]]; then
      printf '%s\n' "${out}"
      return 0
    fi
  fi
  return 1
}

# Fallback: pick a plausible /mnt/c/Users/<Name> (prefer matching $USER).
windows_guess_users_dir() {
  local base="/mnt/c/Users"
  local d name
  [[ -d "${base}" ]] || return 1

  if [[ -n "${USER:-}" && -d "${base}/${USER}" ]]; then
    printf '%s\n' "${base}/${USER}"
    return 0
  fi

  for d in "${base}"/*; do
    [[ -d "${d}" ]] || continue
    name="$(basename "${d}")"
    case "${name}" in
      Public|Default|Default\ User|All\ Users|desktop.ini) continue ;;
    esac
    printf '%s\n' "${d}"
    return 0
  done
  return 1
}

# Prints WSL path to default backup directory (…/Downloads/wslbkup).
windows_default_backup_dir() {
  local profile_win profile_wsl downloads

  if profile_win="$(windows_userprofile_win)"; then
    if profile_wsl="$(windows_to_wsl_path "${profile_win}")"; then
      downloads="${profile_wsl}/Downloads/wslbkup"
      printf '%s\n' "${downloads}"
      return 0
    fi
  fi

  if profile_wsl="$(windows_guess_users_dir)"; then
    downloads="${profile_wsl}/Downloads/wslbkup"
    printf '%s\n' "${downloads}"
    return 0
  fi

  return 1
}

# Suggested archive filename stem: <distro>-<timestamp>
windows_default_archive_name() {
  local distro ts
  distro="$(env_wsl_distro_name 2>/dev/null || true)"
  [[ -n "${distro}" && "${distro}" != "unknown" ]] || distro="$(env_distro_id 2>/dev/null || printf 'wsl')"
  distro="$(printf '%s' "${distro}" | tr -c 'A-Za-z0-9._-' '_' )"
  ts="$(date +%Y%m%d-%H%M%S)"
  printf '%s-%s.tar.zst\n' "${distro}" "${ts}"
}

windows_print_backup_destination() {
  local dir name full
  ui_section "Backup destination (default)"
  if [[ -n "${WSLBKUP_OUTPUT:-}" ]]; then
    ui_kv "Override" "${WSLBKUP_OUTPUT}"
    return 0
  fi

  if dir="$(windows_default_backup_dir)"; then
    name="$(windows_default_archive_name)"
    full="${dir}/${name}"
    ui_kv_path "Directory" "${dir}"
    ui_kv_path "Example" "${full}"
    if [[ -d "${dir}" ]]; then
      if [[ -w "${dir}" ]]; then
        log_ok "default destination writable"
      else
        log_warn "default destination exists but may not be writable"
      fi
    elif [[ -d "$(dirname "${dir}")" ]]; then
      log_info "Downloads/wslbkup will be created on first backup"
    else
      log_warn "parent path missing — is /mnt/c mounted?"
    fi
  else
    ui_item warn "could not resolve Windows Downloads path"
    log_warn "Pass --output <path> when backing up."
  fi
}
