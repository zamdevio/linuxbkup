# shellcheck shell=bash
# Optional Windows mount helpers (present under WSL / similar). No hardcoding in lib/cmd/.

# Convert Windows path like C:\Users\foo to /mnt/c/Users/foo
windows_to_unix_path() {
  local win="$1"
  win="${win//$'\r'/}"
  win="${win%"${win##*[![:space:]]}"}" # rtrim
  win="${win#"${win%%[![:space:]]*}"}" # ltrim
  [[ -n "${win}" ]] || return 1

  # Already a Unix path under a typical mount or home?
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
  if linuxbkup_require_cmd cmd.exe; then
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

# Prints Unix path to Windows Downloads/linuxbkup when a mount is usable.
# Returns 1 when no Windows mount / profile can be resolved.
windows_downloads_backup_dir() {
  local profile_win profile_unix downloads

  if profile_win="$(windows_userprofile_win)"; then
    if profile_unix="$(windows_to_unix_path "${profile_win}")"; then
      downloads="${profile_unix}/Downloads/linuxbkup"
      printf '%s\n' "${downloads}"
      return 0
    fi
  fi

  if profile_unix="$(windows_guess_users_dir)"; then
    downloads="${profile_unix}/Downloads/linuxbkup"
    printf '%s\n' "${downloads}"
    return 0
  fi

  return 1
}
