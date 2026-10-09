# shellcheck shell=bash
# Reinstall preflight guide (peek manifest, PM status, recipes) — R1 split.

# Early guide: peek manifest (no full extract), show PM status + recipes.
# Ready PMs listed with resolved Linux paths; list policy top-10 auto-truncates.
# Returns: 0 = proceed with reinstalls, 2 = skip reinstalls, 1 = abort restore
reinstall_preflight_guide() {
  local backup="$1"
  local kind="$2"
  local -a rows=()
  local -a pms=() missing=() status=()
  local pm count reply path
  local need_node=0
  local missing_n=0

  if [[ "${LINUXBKUP_SKIP_REINSTALL:-0}" -eq 1 ]]; then
    return 0
  fi

  # shellcheck source=lib/constraints/list.sh
  [[ -n "${LINUXBKUP_ROOT:-}" ]] && source "${LINUXBKUP_ROOT}/lib/constraints/list.sh"
  # shellcheck source=lib/core/platform/detect.sh
  [[ -n "${LINUXBKUP_ROOT:-}" ]] && source "${LINUXBKUP_ROOT}/lib/core/platform/detect.sh"
  # shellcheck source=lib/core/compat/compat.sh
  [[ -n "${LINUXBKUP_ROOT:-}" ]] && source "${LINUXBKUP_ROOT}/lib/core/compat/compat.sh"

  reinstall_peek_from_backup "${backup}" "${kind}" rows
  if [[ "${#rows[@]}" -eq 0 ]]; then
    log_verbose "reinstall preflight: no packages/reinstalls.tsv (or empty after filter)"
    return 0
  fi

  # Portable helper (no process substitution — iSH / no /dev/fd).
  # Modifies caller locals `missing` / `missing_n` via bash dynamic scope.
  _pf_missing_refresh() {
    local _t
    _t="$(compat_run_to_tmp reinstall_missing_pms "$@")"
    mapfile -t missing <"${_t}"
    rm -f "${_t}"
    missing_n="${#missing[@]}"
  }

  ui_section "Reinstall preflight"
  ui_item note "Checked packages/reinstalls.tsv without full archive extract"
  ui_kv "Node projects" "${#rows[@]}"

  local _pf_counts_tmp
  _pf_counts_tmp="$(compat_run_to_tmp reinstall_pm_counts rows)"
  while IFS=$'\t' read -r pm count; do
    [[ -z "${pm}" ]] && continue
    pms+=("${pm}")
    status+=("$(reinstall_pm_status_line "${pm}" "${count}")")
    case "${pm}" in
      npm|pnpm|yarn) need_node=1 ;;
    esac
  done <"${_pf_counts_tmp}"
  rm -f "${_pf_counts_tmp}"

  printf '\n'
  ui_section "Package managers"
  reinstall_pm_status_list status

  # Ready-only path check for node runtime
  if [[ "${need_node}" -eq 1 ]] && ! reinstall_pm_resolve node >/dev/null 2>&1; then
    if command -v node >/dev/null 2>&1; then
      log_warn "node on PATH is Windows/interop only ($(command -v node)) — not usable"
    else
      log_warn "Node.js not on PATH (Linux) — required for npm/pnpm/yarn"
    fi
    reinstall_pm_recipe npm
  fi

  _pf_missing_refresh "${pms[@]}"
  if [[ "${missing_n}" -eq 0 ]]; then
    log_ok "all required Node PMs are ready (Linux-native)"
    for pm in "${pms[@]}"; do
      path="$(reinstall_pm_resolve "${pm}" || true)"
      [[ -n "${path}" ]] && log_verbose "${pm} → ${path}"
    done
    return 0
  fi

  ui_kv "Missing PMs" "${missing[*]}"
  printf '\n'
  ui_item note "Install the missing tools, then continue — recipes:"
  for pm in "${missing[@]}"; do
    reinstall_pm_recipe "${pm}"
  done

  reinstall_try_corepack "${missing[@]}" || true
  _pf_missing_refresh "${pms[@]}"
  if [[ "${#missing[@]}" -eq 0 ]]; then
    log_ok "all required Node PMs are ready (Linux-native)"
    return 0
  fi

  if [[ "${LINUXBKUP_YES:-0}" -eq 1 || ! -t 0 ]]; then
    log_warn "still missing: ${missing[*]} — continuing; those projects will skip"
    ui_item note "After installing: linuxbkup -y --reinstall-only <archive|staging>"
    return 0
  fi

  while true; do
    printf '\n'
    ui_item note "[Enter] re-check after you install  ·  [c] continue anyway  ·  [s] skip all reinstalls  ·  [q] quit"
    read -r -p "> " reply || reply="q"
    case "${reply}" in
      q|Q|quit)
        log_skip "restore aborted at reinstall preflight"
        return 1
        ;;
      s|S|skip)
        LINUXBKUP_SKIP_REINSTALL=1
        export LINUXBKUP_SKIP_REINSTALL
        log_info "reinstalls will be skipped this run"
        return 2
        ;;
      c|C|continue)
        log_warn "continuing with missing PMs: ${missing[*]}"
        return 0
        ;;
      ""|r|R|retry|check)
        reinstall_try_corepack "${missing[@]}" || true
        _pf_missing_refresh "${pms[@]}"
        status=()
        local _pf_ct2
        _pf_ct2="$(compat_run_to_tmp reinstall_pm_counts rows)"
        for pm in "${pms[@]}"; do
          count="$(awk -F'\t' -v p="${pm}" '$1==p{print $2}' "${_pf_ct2}")"
          status+=("$(reinstall_pm_status_line "${pm}" "${count}")")
        done
        rm -f "${_pf_ct2}"
        printf '\n'
        ui_section "Package managers (re-check)"
        reinstall_pm_status_list status
        if [[ "${#missing[@]}" -eq 0 ]]; then
          log_ok "all required Node PMs are ready (Linux-native)"
          return 0
        fi
        log_warn "still missing: ${missing[*]}"
        for pm in "${missing[@]}"; do
          reinstall_pm_recipe "${pm}"
        done
        ;;
      *)
        log_warn "unknown choice — try Enter / c / s / q"
        ;;
    esac
  done
}
