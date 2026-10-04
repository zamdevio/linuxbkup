# shellcheck shell=bash
# Parallelism policy for checksums, du batches, pack threads, verify.
#
# LINUXBKUP_WORKERS (from -w/--workers) is the *cap* (default 4).
# Per-op helpers pick 1..cap from item count / op rules.

LINUXBKUP_WORKERS_DEFAULT=4
LINUXBKUP_WORKERS_HARD_MAX=16

# Normalize / clamp LINUXBKUP_WORKERS. Call after parse.
linuxbkup_workers_init() {
  local w="${LINUXBKUP_WORKERS:-${LINUXBKUP_WORKERS_DEFAULT}}"
  if [[ ! "${w}" =~ ^[0-9]+$ ]]; then
    log_fatal "--workers must be a positive integer (got: ${w})"
    return 1
  fi
  if [[ "${w}" -lt 1 ]]; then
    log_fatal "--workers must be >= 1"
    return 1
  fi
  if [[ "${w}" -gt "${LINUXBKUP_WORKERS_HARD_MAX}" ]]; then
    log_warn "workers ${w} capped at ${LINUXBKUP_WORKERS_HARD_MAX}"
    w="${LINUXBKUP_WORKERS_HARD_MAX}"
  fi
  local cpus=""
  if [[ -r /proc/cpuinfo ]]; then
    cpus="$(grep -c '^processor' /proc/cpuinfo 2>/dev/null || true)"
  fi
  if [[ "${cpus}" =~ ^[0-9]+$ && "${cpus}" -ge 1 && "${w}" -gt "${cpus}" ]]; then
    w="${cpus}"
  fi
  LINUXBKUP_WORKERS="${w}"
  export LINUXBKUP_WORKERS
}

# Workers / threads for an op. Args: count [op]
# op: checksum|verify|du|pack|default
linuxbkup_workers_for() {
  local count="${1:-0}"
  local op="${2:-default}"
  local max="${LINUXBKUP_WORKERS:-${LINUXBKUP_WORKERS_DEFAULT}}"
  local n=1

  [[ "${count}" =~ ^[0-9]+$ ]] || count=0
  [[ "${max}" =~ ^[0-9]+$ ]] || max="${LINUXBKUP_WORKERS_DEFAULT}"
  [[ "${max}" -ge 1 ]] || max=1

  case "${op}" in
    pack)
      # zstd -T<N>: one stream, N compression threads — use full cap
      n="${max}"
      ;;
    du)
      # Few independent path roots; scale sooner than checksum
      if [[ "${count}" -le 1 ]]; then n=1
      elif [[ "${count}" -lt 6 ]]; then n=2
      elif [[ "${count}" -lt 16 ]]; then n=3
      else n="${max}"
      fi
      ;;
    checksum|verify)
      if [[ "${count}" -lt 16 ]]; then n=1
      elif [[ "${count}" -lt 64 ]]; then n=2
      elif [[ "${count}" -lt 256 ]]; then n=3
      else n="${max}"
      fi
      ;;
    *)
      if [[ "${count}" -lt 16 ]]; then n=1
      elif [[ "${count}" -lt 64 ]]; then n=2
      else n="${max}"
      fi
      ;;
  esac

  ((n > max)) && n="${max}"
  if [[ "${op}" != "pack" ]]; then
    ((n > count && count > 0)) && n="${count}"
  fi
  ((n < 1)) && n=1
  printf '%s\n' "${n}"
}

# Print a one-line worker note for the current step. Args: op workers [detail]
linuxbkup_workers_note() {
  local op="$1" n="$2" detail="${3:-}"
  local msg
  case "${op}" in
    pack) msg="pack: zstd using ${n} thread(s)" ;;
    du) msg="du: ${n} parallel path(s)" ;;
    checksum) msg="checksums: ${n} worker(s)" ;;
    verify) msg="verify: ${n} worker(s)" ;;
    *) msg="${op}: ${n} worker(s)" ;;
  esac
  [[ -n "${detail}" ]] && msg+=" — ${detail}"
  ui_item note "${msg}"
}
