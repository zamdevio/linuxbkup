# shellcheck shell=bash
# Distro / arch / WSL detection.

env_distro_pretty() {
  local name="" version="" id=""
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    name="${NAME:-Linux}"
    version="${VERSION:-${VERSION_ID:-}}"
    id="${ID:-unknown}"
    if [[ -n "${version}" ]]; then
      printf '%s %s\n' "${name}" "${version}"
    else
      printf '%s\n' "${name}"
    fi
    return 0
  fi
  printf '%s\n' "unknown"
}

env_distro_id() {
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    printf '%s\n' "${ID:-unknown}"
    return 0
  fi
  printf '%s\n' "unknown"
}

env_distro_version_id() {
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    printf '%s\n' "${VERSION_ID:-unknown}"
    return 0
  fi
  printf '%s\n' "unknown"
}

env_arch() {
  uname -m 2>/dev/null || printf '%s\n' "unknown"
}

# Prints: wsl2 | wsl1 | not-wsl | unknown
env_wsl_kind() {
  if [[ -n "${WSL_INTEROP:-}" || -n "${WSL_DISTRO_NAME:-}" ]]; then
    if [[ -r /proc/version ]] && grep -qi microsoft /proc/version; then
      if [[ -d /run/WSL ]] || grep -qi 'WSL2\|microsoft-standard-WSL2' /proc/version 2>/dev/null; then
        printf '%s\n' "wsl2"
        return 0
      fi
      printf '%s\n' "wsl1"
      return 0
    fi
    printf '%s\n' "wsl2"
    return 0
  fi
  if [[ -r /proc/version ]] && grep -qi microsoft /proc/version; then
    if grep -qi 'WSL2\|microsoft-standard-WSL2' /proc/version; then
      printf '%s\n' "wsl2"
    else
      printf '%s\n' "wsl1"
    fi
    return 0
  fi
  printf '%s\n' "not-wsl"
}

env_wsl_distro_name() {
  if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
    printf '%s\n' "${WSL_DISTRO_NAME}"
    return 0
  fi
  # Best-effort from /etc/hostname
  if [[ -r /etc/hostname ]]; then
    tr -d '\n' </etc/hostname
    printf '\n'
    return 0
  fi
  printf '%s\n' "unknown"
}

env_print_distribution() {
  local pretty id ver arch wsl name
  pretty="$(env_distro_pretty)"
  id="$(env_distro_id)"
  ver="$(env_distro_version_id)"
  arch="$(env_arch)"
  wsl="$(env_wsl_kind)"
  name="$(env_wsl_distro_name)"

  ui_section "Distribution"
  ui_kv "Distro" "${pretty}"
  ui_kv "ID" "${id}"
  ui_kv "Version" "${ver}"
  ui_kv "Arch" "${arch}"
  if [[ "${wsl}" != "not-wsl" ]]; then
    ui_kv "WSL" "${wsl} (${name})"
  else
    ui_kv "WSL" "${wsl}"
  fi
}
