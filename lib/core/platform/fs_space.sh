# shellcheck shell=bash
# Free-space helpers (used by space preflight in a later phase).

# Bytes available on the filesystem that will hold <path> (parent if missing).
# Prints an integer byte count; returns 1 if unreadable.
platform_fs_avail_bytes() {
  local path="$1" probe=""
  [[ -n "${path}" ]] || return 1

  if [[ -e "${path}" ]]; then
    probe="${path}"
  else
    probe="$(dirname "${path}")"
  fi
  while [[ ! -d "${probe}" && "${probe}" != "/" && "${probe}" != "." ]]; do
    probe="$(dirname "${probe}")"
  done
  [[ -d "${probe}" ]] || return 1

  # POSIX df -k; use available column (4th on GNU, portable enough for Linux).
  local avail
  avail="$(df -Pk "${probe}" 2>/dev/null | awk 'NR==2 { print $4; exit }')"
  [[ -n "${avail}" && "${avail}" =~ ^[0-9]+$ ]] || return 1
  # df -k reports 1K-blocks
  printf '%s\n' "$((avail * 1024))"
}

# Human-readable available space for <path>, or empty + return 1.
platform_fs_avail_human() {
  local bytes
  bytes="$(platform_fs_avail_bytes "$1")" || return 1
  if command -v numfmt >/dev/null 2>&1; then
    numfmt --to=iec --suffix=B "${bytes}"
  else
    printf '%sB\n' "${bytes}"
  fi
}
