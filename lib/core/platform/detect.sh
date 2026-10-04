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
