# shellcheck shell=bash
# Home-directory / user selection.

# Resolve target Linux username (not Windows).
# Under sudo without -u/--user, prefer SUDO_USER so home/secrets land in the
# invoking user's tree — not /root. Explicit -u root still targets root.
env_resolve_user() {
  if [[ -n "${LINUXBKUP_USER:-}" ]]; then
    printf '%s\n' "${LINUXBKUP_USER}"
    return 0
  fi
  if [[ "$(id -u)" -eq 0 && -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    printf '%s\n' "${SUDO_USER}"
    return 0
  fi
  printf '%s\n' "${USER:-$(id -un)}"
}

# True when we remapped root→SUDO_USER (no explicit --user).
env_sudo_user_remap() {
  [[ "$(id -u)" -eq 0 \
    && -z "${LINUXBKUP_USER:-}" \
    && -n "${SUDO_USER:-}" \
    && "${SUDO_USER}" != "root" ]]
}

env_user_home() {
  local user="$1"
  local home
  home="$(getent passwd "${user}" 2>/dev/null | cut -d: -f6 || true)"
  if [[ -n "${home}" && -d "${home}" ]]; then
    printf '%s\n' "${home}"
    return 0
  fi
  if [[ -d "/home/${user}" ]]; then
    printf '%s\n' "/home/${user}"
    return 0
  fi
  return 1
}

# List usernames that look like real homes under /home (exclude lost+found).
env_list_home_users() {
  local d base
  [[ -d /home ]] || return 0
  for d in /home/*; do
    [[ -d "${d}" ]] || continue
    base="$(basename "${d}")"
    [[ "${base}" == "lost+found" ]] && continue
    printf '%s\n' "${base}"
  done
}

env_print_users() {
  local current selected home count=0
  current="$(id -un 2>/dev/null || printf '%s\n' "?")"
  selected="$(env_resolve_user)"

  ui_section "Users"
  ui_kv "Login" "${current}"
  if [[ -n "${LINUXBKUP_USER:-}" ]]; then
    ui_kv "Target" "${selected} (--user)"
  else
    ui_kv "Target" "${selected} (default)"
  fi

  if home="$(env_user_home "${selected}")"; then
    ui_kv_path "Home" "${home}"
    log_ok "home resolved for ${selected}"
  else
    ui_kv "Home" "(missing)"
    log_warn "no home directory for user: ${selected}"
  fi

  ui_item note "Homes under /home:"
  local _hometmp
  _hometmp="$(mktemp "${TMPDIR:-/tmp}/linuxbkup-homes.XXXXXX")" || return 0
  env_list_home_users >"${_hometmp}" || true
  while IFS= read -r u; do
    [[ -z "${u}" ]] && continue
    count=$((count + 1))
    if [[ "${u}" == "${selected}" ]]; then
      ui_item ok "${u}  (selected)"
    else
      ui_item off "${u}"
    fi
  done <"${_hometmp}"
  rm -f "${_hometmp}"

  if [[ "${count}" -eq 0 ]]; then
    ui_item note "(none)"
  elif [[ "${count}" -gt 1 && -z "${LINUXBKUP_USER:-}" ]]; then
    log_info "Multiple homes detected — pass --user <name> to target another."
  fi
}
