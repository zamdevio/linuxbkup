# shellcheck shell=bash
# Parallel sha256 under staging (worker policy from lib/core/workers.sh).

# Tear down checksum workers quietly (TERM then KILL — never SIGINT).
# SIGINT teardown + monitor mode re-raises INT to the parent → fake quit.
_checksum_kill_workers() {
  local pid
  for pid in "$@"; do
    [[ -z "${pid}" ]] && continue
    kill -TERM "${pid}" 2>/dev/null || true
    pkill -TERM -P "${pid}" 2>/dev/null || true
  done
  sleep 0.05
  for pid in "$@"; do
    [[ -z "${pid}" ]] && continue
    kill -KILL "${pid}" 2>/dev/null || true
    pkill -KILL -P "${pid}" 2>/dev/null || true
  done
  # Reap without letting a stray status become "our" SIGINT
  wait 2>/dev/null || true
}

# Write checksums.sha256 for files under stage (relative paths).
# Uses -w/--workers cap with safe per-count defaults; live progress + ETA.
archive_write_checksums() {
  local stage="$1"
  local out="${stage}/checksums.sha256"
  local list total=0 n=0 workers=1
  local work oldpwd i donef last_n=-1 rel pids action="" had_m=0
  local worker_sh=""
  local -a wpids=()

  if [[ "${LINUXBKUP_DRY_RUN:-0}" -eq 1 ]]; then
    log_info "dry-run — would write checksums.sha256"
    return 0
  fi

  # shellcheck source=lib/core/workers.sh
  source "${LINUXBKUP_ROOT}/lib/core/workers.sh"
  if ! declare -F linuxbkup_op_begin >/dev/null 2>&1; then
    # shellcheck source=lib/core/interrupt.sh
    source "${LINUXBKUP_ROOT}/lib/core/interrupt.sh"
  fi

  worker_sh="${LINUXBKUP_ROOT}/lib/archive/_checksum_worker.sh"

  list="$(mktemp "${TMPDIR:-/tmp}/linuxbkup-cksum.XXXXXX")"
  find "${stage}" -type f ! -name 'checksums.sha256' -printf '%P\n' >"${list}" || true
  total="$(wc -l <"${list}" | tr -d ' ')"
  : >"${out}"
  if [[ "${total}" -eq 0 ]]; then
    rm -f "${list}"
    log_ok "checksums written (0 files)"
    return 0
  fi

  workers="$(linuxbkup_workers_for "${total}" checksum)"
  linuxbkup_workers_note checksum "${workers}" "${total} files"
  linuxbkup_op_begin "checksum" "" 0 1
  work="$(mktemp -d "${TMPDIR:-/tmp}/linuxbkup-cksumw.XXXXXX")"
  donef="${work}/done.count"
  : >"${donef}"

  term_progress_set_extra "${workers}w"
  term_progress_begin "${total}" "Computing checksums (${workers} workers)"

  oldpwd="${PWD}"
  if ! cd "${stage}"; then
    term_progress_end
    rm -f "${list}"
    rm -rf "${work}"
    linuxbkup_op_end
    log_fatal "cannot enter staging: ${stage}"
    return 1
  fi

  for ((i = 0; i < workers; i++)); do
    : >"${work}/part.${i}"
    : >"${work}/out.${i}"
  done
  i=0
  while IFS= read -r rel || [[ -n "${rel}" ]]; do
    [[ -z "${rel}" ]] && continue
    printf '%s\n' "${rel}" >>"${work}/part.$((i % workers))"
    i=$((i + 1))
  done <"${list}"

  # Disable monitor mode while workers run — set -m + killed jobs dumps the
  # command text and can re-raise SIGINT to the parent (instant quit).
  [[ $- == *m* ]] && had_m=1
  set +m 2>/dev/null || true

  for ((i = 0; i < workers; i++)); do
    [[ -s "${work}/part.${i}" ]] || continue
    bash "${worker_sh}" \
      "${work}/part.${i}" \
      "${work}/out.${i}" \
      "${donef}" \
      "${work}/failed" &
    wpids+=("$!")
  done

  while true; do
    if linuxbkup_interrupt_pending; then
      declare -F term_live_park >/dev/null 2>&1 && term_live_park
      _checksum_kill_workers "${wpids[@]+"${wpids[@]}"}"
      break
    fi
    n="$(wc -l <"${donef}" 2>/dev/null | tr -d ' ')"
    [[ "${n}" =~ ^[0-9]+$ ]] || n=0
    ((n > total)) && n="${total}"
    if [[ "${n}" -ne "${last_n}" ]]; then
      term_progress_update "${n}" "hashing…"
      last_n="${n}"
    fi
    pids=""
    for i in "${wpids[@]+"${wpids[@]}"}"; do
      if kill -0 "${i}" 2>/dev/null; then
        pids=1
        break
      fi
    done
    if [[ -z "${pids}" ]]; then
      wait 2>/dev/null || true
      n="$(wc -l <"${donef}" 2>/dev/null | tr -d ' ')"
      [[ "${n}" =~ ^[0-9]+$ ]] || n=0
      ((n > total)) && n="${total}"
      term_progress_update "${total}" "done"
      break
    fi
    sleep 0.12
  done
  wait 2>/dev/null || true

  [[ "${had_m}" -eq 1 ]] && set -m 2>/dev/null || true

  cd "${oldpwd}" || true
  term_progress_end

  if linuxbkup_interrupt_pending; then
    rm -f "${list}"
    rm -rf "${work}"
    rm -f "${out}"
    linuxbkup_interrupt_resolve
    action="${LINUXBKUP_INTERRUPT_RESULT}"
    linuxbkup_op_end
    if [[ "${action}" == "retry" || "${action}" == "continue" || "${action}" == "skip" ]]; then
      log_info "checksum: re-running from scratch"
      archive_write_checksums "${stage}"
      return $?
    fi
    linuxbkup_interrupt_arm
    return 1
  fi

  : >"${out}"
  for ((i = 0; i < workers; i++)); do
    [[ -s "${work}/out.${i}" ]] && cat "${work}/out.${i}" >>"${out}"
  done
  if [[ -f "${work}/failed" ]]; then
    while IFS= read -r rel; do
      [[ -z "${rel}" ]] && continue
      log_warn "checksum failed: ${rel}"
    done <"${work}/failed"
  fi

  linuxbkup_op_end
  rm -f "${list}"
  rm -rf "${work}"

  n="$(wc -l <"${out}" | tr -d ' ')"
  log_ok "checksums written (${n} files, ${workers} workers)"
}
