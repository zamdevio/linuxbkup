# shellcheck shell=bash

linuxbkup_cmd_verify() {
  if cmd_want_help "$@"; then
    linuxbkup_cmd_help verify
    return 0
  fi

  local target="${1:-}"
  if [[ -z "${target}" ]]; then
    log_fatal "Usage: linuxbkup verify <archive.tar.zst|staging-dir>"
    linuxbkup_cmd_help verify
    return 2
  fi

  # shellcheck source=lib/core/context.sh
  source "${LINUXBKUP_ROOT}/lib/core/context.sh"
  # shellcheck source=lib/archive/verify.sh
  source "${LINUXBKUP_ROOT}/lib/archive/verify.sh"

  local kind=""
  if [[ -d "${target}" ]]; then
    if archive_looks_like_staging "${target}"; then
      kind="staging"
    else
      log_fatal "directory is not a linuxbkup staging root: ${target}"
      ui_item note "Expected checksums.sha256 and/or metadata/ (or INDEX)"
      return 1
    fi
  elif [[ -f "${target}" ]]; then
    kind="archive"
  else
    log_fatal "path not found: ${target}"
    return 1
  fi

  if [[ "${kind}" == "staging" ]]; then
    cmd_context_begin verify \
      --desc "Verify staging directory checksums / manifests." \
      --required sha256sum \
      --optional tar zstd age
  else
    cmd_context_begin verify \
      --desc "Verify archive integrity / manifests." \
      --required tar zstd sha256sum \
      --optional age
  fi

  ui_kv "Kind" "${kind}"
  ui_kv_path "Target" "${target}"
  printf '\n'
  linuxbkup_op_begin "verify" "${target}" 0 1

  local root="" tmp=""
  local ck_rc=0

  if [[ "${kind}" == "staging" ]]; then
    root="${target}"
    ui_section "Staging (in place)"
    log_ok "using staging directory — no extract"
  else
    if [[ "${target}" != *.tar.zst && "${target}" != *.tzst ]]; then
      log_warn "unexpected extension — attempting tar.zst read anyway"
    fi
    tmp="$(mktemp -d "${TMPDIR:-/tmp}/linuxbkup-verify.XXXXXX")"
    # EXIT only — INT stays with safety_on_int (menu); cleanup on quit via EXIT
    trap 'rm -rf "'"${tmp}"'"' EXIT
    ui_section "Extract (temp)"
    linuxbkup_op_begin "verify-extract" "${target}" 0 1
    set +e
    zstd -dcq "${target}" | tar --warning=no-timestamp -C "${tmp}" -xf -
    local extract_rc=$?
    set -e
    if linuxbkup_interrupt_pending || [[ "${extract_rc}" -ne 0 && "${LINUXBKUP_WAS_INTERRUPTED:-0}" -eq 1 ]]; then
      LINUXBKUP_WAS_INTERRUPTED=1
      local vaction
      linuxbkup_interrupt_resolve
      vaction="${LINUXBKUP_INTERRUPT_RESULT}"
      case "${vaction}" in
        retry|continue|skip)
          rm -rf "${tmp}"
          trap - EXIT
          linuxbkup_op_end
          linuxbkup_cmd_verify "${target}"
          return $?
          ;;
        *)
          return 1
          ;;
      esac
    fi
    if [[ "${extract_rc}" -ne 0 ]]; then
      log_fatal "failed to extract archive"
      return 1
    fi
    log_ok "extracted for verification"
    root="${tmp}"
    linuxbkup_op_begin "verify" "${target}" 0 1
  fi

  ck_rc=0
  if archive_verify_checksums_inplace "${root}"; then
    ck_rc=0
  else
    ck_rc=$?
  fi
  if [[ "${ck_rc}" -eq 1 ]]; then
    return 1
  fi
  if [[ "${ck_rc}" -eq 2 ]]; then
    if [[ "${kind}" == "staging" ]]; then
      log_fatal "staging root missing checksums.sha256 — cannot verify"
      return 1
    fi
    log_warn "continuing without checksum verification"
  fi

  archive_print_verify_summary "${root}"
  archive_verify_schema "${root}"

  if [[ -n "${tmp}" ]]; then
    rm -rf "${tmp}"
    trap - EXIT
  fi

  printf '\n'
  linuxbkup_op_end
  log_ok "verify complete"
}
