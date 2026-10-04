# shellcheck shell=bash
# Parallel sha256 under staging (worker policy from lib/core/workers.sh).

# Write checksums.sha256 for files under stage (relative paths).
# Uses -w/--workers cap with safe per-count defaults; live progress + ETA.
archive_write_checksums() {
  local stage="$1"
  local out="${stage}/checksums.sha256"
  local list total=0 n=0 workers=1
  local work oldpwd i donef last_n=-1 rel pids
  local -a wpids=()

  if [[ "${LINUXBKUP_DRY_RUN:-0}" -eq 1 ]]; then
    log_info "dry-run — would write checksums.sha256"
    return 0
  fi

  # shellcheck source=lib/core/workers.sh
  source "${LINUXBKUP_ROOT}/lib/core/workers.sh"

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

  # Each worker: batch sha256sum; append one newline to donef per file completed
  for ((i = 0; i < workers; i++)); do
    [[ -s "${work}/part.${i}" ]] || continue
    (
      batch=32
      buf=()
      flush() {
        local x j
        [[ "${#buf[@]}" -eq 0 ]] && return 0
        if ! sha256sum -- "${buf[@]}" >>"${work}/out.${i}" 2>/dev/null; then
          for x in "${buf[@]}"; do
            if ! sha256sum -- "${x}" >>"${work}/out.${i}" 2>/dev/null; then
              printf '%s\n' "${x}" >>"${work}/failed"
            fi
          done
        fi
        for ((j = 0; j < ${#buf[@]}; j++)); do
          printf '\n' >>"${donef}"
        done
        buf=()
      }
      while IFS= read -r f || [[ -n "${f}" ]]; do
        [[ -z "${f}" ]] && continue
        buf+=("${f}")
        if [[ "${#buf[@]}" -ge "${batch}" ]]; then
          flush
        fi
      done <"${work}/part.${i}"
      flush
    ) &
    wpids+=("$!")
  done

  while true; do
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
      wait || true
      n="$(wc -l <"${donef}" 2>/dev/null | tr -d ' ')"
      [[ "${n}" =~ ^[0-9]+$ ]] || n=0
      ((n > total)) && n="${total}"
      term_progress_update "${total}" "done"
      break
    fi
    sleep 0.12
  done
  wait || true

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

  cd "${oldpwd}" || true
  term_progress_end
  rm -f "${list}"
  rm -rf "${work}"

  n="$(wc -l <"${out}" | tr -d ' ')"
  log_ok "checksums written (${n} files, ${workers} workers)"
}
