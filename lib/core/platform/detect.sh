# shellcheck shell=bash
# Host kind: linux | wsl | unknown. Distro family stays in lib/env.

# True when Windows drive mounts look available (typically WSL).
platform_has_windows_mount() {
  [[ -d /mnt/c/Users ]] || [[ -d /mnt/c/Windows ]]
}

# Prints: linux | wsl | unknown
platform_kind() {
  if [[ -n "${WSL_INTEROP:-}" || -n "${WSL_DISTRO_NAME:-}" ]]; then
    printf '%s\n' "wsl"
    return 0
  fi
  if [[ -r /proc/version ]] && grep -qi microsoft /proc/version; then
    printf '%s\n' "wsl"
    return 0
  fi
  if platform_has_windows_mount; then
    # Mount present without clear WSL markers — still treat as wsl-capable host
    printf '%s\n' "wsl"
    return 0
  fi
  case "$(uname -s 2>/dev/null || true)" in
    Linux) printf '%s\n' "linux" ;;
    *) printf '%s\n' "unknown" ;;
  esac
}

# True if path is a Windows drive / interop binary (never use for Linux restore).
# Matches /mnt/<drive>/…, *.exe/*.cmd/*.bat/*.ps1 (case-insensitive).
platform_path_is_windows_interop() {
  local p="${1:-}" real="" base=""
  [[ -n "${p}" ]] || return 1
  real="$(readlink -f "${p}" 2>/dev/null || true)"
  [[ -n "${real}" ]] || real="${p}"
  base="${real##*/}"
  case "${base}" in
    *.[eE][xX][eE]|*.[cC][mM][dD]|*.[bB][aA][tT]|*.[pP][sS]1) return 0 ;;
  esac
  case "${real}" in
    /mnt/[a-zA-Z]/*|/mnt/[a-zA-Z]) return 0 ;;
    /host_mnt/*) return 0 ;;
  esac
  return 1
}

# First Linux-native executable named $1 on PATH (skips Windows/interop shims).
# Prints absolute path; returns 1 if none.
platform_linux_command() {
  local name="$1"
  local cand="" out=""
  local -a cands=()

  [[ -n "${name}" ]] || return 1
  # Avoid bash process substitution — /dev/fd is missing on some iSH hosts.
  out="$(type -aP "${name}" 2>/dev/null || true)"
  if [[ -z "${out}" ]]; then
    cand="$(command -v "${name}" 2>/dev/null || true)"
    [[ -n "${cand}" ]] && out="${cand}"
  fi
  [[ -n "${out}" ]] || return 1
  mapfile -t cands <<<"${out}"
  for cand in "${cands[@]+"${cands[@]}"}"; do
    [[ -n "${cand}" ]] || continue
    if platform_path_is_windows_interop "${cand}"; then
      declare -F log_verbose >/dev/null 2>&1 && log_verbose "ignore Windows/interop ${name}: ${cand}"
      continue
    fi
    [[ -x "${cand}" || -f "${cand}" ]] || continue
    printf '%s\n' "${cand}"
    return 0
  done
  return 1
}
