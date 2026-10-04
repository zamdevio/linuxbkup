# shellcheck shell=bash

wslbkup_cmd_verify() {
  if cmd_want_help "$@"; then
    wslbkup_cmd_help verify
    return 0
  fi

  local backup="${1:-}"
  if [[ -z "${backup}" ]]; then
    log_fatal "Usage: wslbkup verify <backup>"
    wslbkup_cmd_help verify
    return 2
  fi

  # shellcheck source=lib/core/context.sh
  source "${WSLBKUP_ROOT}/lib/core/context.sh"

  cmd_context_begin verify \
    --desc "Verify archive integrity / manifests." \
    --required tar zstd sha256sum \
    --optional age

  ui_kv_path "Archive" "${backup}"

  if [[ ! -f "${backup}" ]]; then
    log_fatal "archive not found: ${backup}"
    return 1
  fi

  if [[ "${backup}" != *.tar.zst && "${backup}" != *.tzst ]]; then
    log_warn "unexpected extension — attempting tar.zst read anyway"
  fi

  local tmp
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/wslbkup-verify.XXXXXX")"
  trap 'rm -rf "'"${tmp}"'"' EXIT INT TERM

  ui_section "Extract (temp)"
  if ! zstd -dcq "${backup}" | tar -C "${tmp}" -xf -; then
    log_fatal "failed to extract archive"
    return 1
  fi
  log_ok "extracted for verification"

  if [[ ! -f "${tmp}/checksums.sha256" ]]; then
    log_warn "no checksums.sha256 in archive"
  else
    ui_section "Checksums"
    if (
      cd "${tmp}" && sha256sum -c checksums.sha256 --quiet
    ); then
      log_ok "all checksums matched"
    else
      log_fatal "checksum mismatch"
      return 1
    fi
  fi

  if [[ -f "${tmp}/metadata/distro.env" ]]; then
    ui_section "Metadata"
    while IFS= read -r line; do
      [[ -z "${line}" || "${line}" == \#* ]] && continue
      ui_kv "${line%%=*}" "${line#*=}"
    done <"${tmp}/metadata/distro.env"
  fi

  if [[ -f "${tmp}/packages/apt.manual" ]]; then
    local n
    n="$(wc -l <"${tmp}/packages/apt.manual" | tr -d ' ')"
    ui_kv "APT manuals" "${n}"
  fi

  rm -rf "${tmp}"
  trap - EXIT INT TERM
  printf '\n'
  log_ok "verify complete"
}
