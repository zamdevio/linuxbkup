# shellcheck source=lib/core/common.sh
# (callers already have linuxbkup_require_cmd)

# shellcheck source=lib/core/compat/compat.sh
[[ -n "${LINUXBKUP_ROOT:-}" ]] && source "${LINUXBKUP_ROOT}/lib/core/compat/compat.sh"

archive_pack_tar_zst() {
  local stage="$1"
  local dest="$2"
  local dest_dir size threads tmp pack_rc=0 action=""

  if [[ -z "${dest}" ]]; then
    log_fatal "refusing to pack: empty destination path (pass -o/--output)"
    return 1
  fi

  dest_dir="$(dirname -- "${dest}")"
  if [[ "${LINUXBKUP_DRY_RUN:-0}" -eq 1 ]]; then
    log_info "dry-run — would create $(term_path_link "${dest}")"
    return 0
  fi

  # shellcheck source=lib/core/workers.sh
  source "${LINUXBKUP_ROOT}/lib/core/workers.sh"
  threads="$(linuxbkup_workers_for 1 pack)"

  log_info "ensuring destination directory…"
  if ! mkdir -p "${dest_dir}"; then
    log_fatal "cannot create destination directory: ${dest_dir}"
    return 1
  fi
  if [[ ! -w "${dest_dir}" ]]; then
    log_fatal "destination directory not writable: ${dest_dir}"
    return 1
  fi

  if [[ -e "${dest}" ]]; then
    safety_require_force_overwrite "${dest}" || return 1
  fi

  # Atomic: pack to sibling .tmp, verify stream, then mv
  tmp="${dest}.tmp.$$"
  rm -f "${tmp}" 2>/dev/null || true

  linuxbkup_workers_note pack "${threads}" "tar | zstd -T${threads}"
  linuxbkup_op_begin "pack" "${dest}" 0 1
  term_progress_status "Packing tar.zst (${threads} threads) → ${dest}"

  _archive_pack_pipeline() {
    if declare -F compat_tar_pack_stream >/dev/null 2>&1; then
      compat_tar_pack_stream "${stage}" '*.sock' \
        | compat_zstd_compress "${tmp}" "${threads}"
    else
      tar -C "${stage}" --exclude='*.sock' -cf - . 2>/dev/null \
        | zstd -T"${threads}" -q -o "${tmp}"
    fi
  }

  linuxbkup_interrupt_arm
  set +e
  linuxbkup_without_monitor _archive_pack_pipeline
  pack_rc=$?
  set -e

  if linuxbkup_interrupt_pending \
    || [[ "${pack_rc}" -eq 130 || "${pack_rc}" -eq 141 || "${pack_rc}" -eq 143 ]]; then
    linuxbkup_interrupt_disarm
    declare -F term_live_park >/dev/null 2>&1 && term_live_park
    pkill -TERM -P "${BASHPID:-$$}" -x tar 2>/dev/null || true
    pkill -TERM -P "${BASHPID:-$$}" -x zstd 2>/dev/null || true
    wait 2>/dev/null || true
    LINUXBKUP_WAS_INTERRUPTED=1
    rm -f "${tmp}" 2>/dev/null || true

    linuxbkup_interrupt_resolve
    action="${LINUXBKUP_INTERRUPT_RESULT}"
    linuxbkup_op_end
    if [[ "${action}" == "retry" || "${action}" == "continue" || "${action}" == "skip" ]]; then
      log_info "pack: re-running tar|zstd (overwrite partial)"
      archive_pack_tar_zst "${stage}" "${dest}"
      return $?
    fi
    linuxbkup_interrupt_arm
    return 1
  fi

  declare -F term_live_park >/dev/null 2>&1 && term_live_park
  linuxbkup_op_end

  if [[ "${pack_rc}" -ne 0 ]]; then
    log_fatal "tar|zstd failed writing ${dest}"
    rm -f "${tmp}" 2>/dev/null || true
    return 1
  fi

  if [[ ! -f "${tmp}" ]]; then
    log_fatal "archive missing after pack: ${tmp}"
    return 1
  fi

  # Verify the tmp stream is readable before rename (atomic commit)
  if ! zstd -t "${tmp}" >/dev/null 2>&1; then
    log_fatal "packed archive failed zstd integrity check — not renaming"
    rm -f "${tmp}" 2>/dev/null || true
    return 1
  fi
  if ! (zstd -dcq "${tmp}" 2>/dev/null | tar -tf - >/dev/null 2>&1); then
    log_fatal "packed archive failed tar list check — not renaming"
    rm -f "${tmp}" 2>/dev/null || true
    return 1
  fi

  if ! mv -f "${tmp}" "${dest}"; then
    log_fatal "failed to rename archive into place: ${dest}"
    rm -f "${tmp}" 2>/dev/null || true
    return 1
  fi

  log_ok "archive written (atomic)"
  ui_kv_path "Archive" "${dest}"
  size="$(du -sh "${dest}" 2>/dev/null | awk '{print $1}')"
  ui_kv "Size" "${size:-?}"
}
