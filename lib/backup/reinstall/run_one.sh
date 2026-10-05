# shellcheck shell=bash
# reinstall_run_one — one project install (split from run.sh for size budget).
# Ctrl+C menu: r=retry · s=skip · c=continue (partial kept) · q=quit batch.
# Soft-quit: q stops the batch; never exit 130 the whole restore process.

REINSTALL_LAST_RC=0
REINSTALL_LAST_REASON=""
REINSTALL_LAST_LOG=""
REINSTALL_INTERRUPT_QUIT=0

reinstall_run_one() {
  local home="$1" rel="$2" pm="$3" cmd="$4"
  local dir="${home}/${rel}"
  local rc=0
  local pmbin="" run_cmd="" log_file=""
  local quiet=1
  local -a env_args=()

  REINSTALL_LAST_RC=0
  REINSTALL_LAST_REASON=""
  REINSTALL_LAST_LOG=""

  if [[ "${LINUXBKUP_VERBOSE:-0}" -eq 1 || "${LINUXBKUP_DEBUG:-0}" -eq 1 ]]; then
    quiet=0
  fi

  if [[ ! -d "${dir}" ]]; then
    log_warn "reinstall skip — missing ${dir}"
    REINSTALL_LAST_REASON="missing ${rel}"
    return 2
  fi
  if [[ ! -f "${dir}/package.json" ]]; then
    log_warn "reinstall skip — no package.json in ${rel}"
    REINSTALL_LAST_REASON="no package.json"
    return 2
  fi

  # Workspace roots first: members must exist or pnpm/npm ERR_*PKG_NOT_FOUND
  if [[ "${pm}" == "pnpm" || "${pm}" == "npm" ]]; then
    local -a wmiss=()
    mapfile -t wmiss < <(reinstall_workspace_missing "${dir}" || true)
    if [[ "${#wmiss[@]}" -gt 0 ]]; then
      local -a real_miss=() pat_miss=()
      local m
      for m in "${wmiss[@]}"; do
        if [[ "${m}" == PATTERN:* ]]; then
          pat_miss+=("${m#PATTERN:}")
        else
          real_miss+=("${m}")
        fi
      done
      if [[ "${#real_miss[@]}" -gt 0 || "${#pat_miss[@]}" -gt 0 ]]; then
        if [[ "${#real_miss[@]}" -gt 0 ]]; then
          log_warn "workspace member(s) missing from restored tree: ${real_miss[*]}"
          REINSTALL_LAST_REASON="workspace member(s) missing: ${real_miss[*]}"
        fi
        if [[ "${#pat_miss[@]}" -gt 0 ]]; then
          log_warn "workspace glob matched no dir: ${pat_miss[*]}"
          REINSTALL_LAST_REASON="${REINSTALL_LAST_REASON:+${REINSTALL_LAST_REASON}; }workspace glob empty: ${pat_miss[*]}"
        fi
        ui_item note "check backup classification — source packages must be kept (not regenerable)"
        ui_item note "then: linuxbkup -y --reinstall-only <archive|staging>"
        return 2
      fi
    fi
  fi

  pmbin="$(reinstall_pm_resolve "${pm}")" || {
    if command -v "${pm}" >/dev/null 2>&1; then
      log_warn "reinstall skip — '${pm}' is Windows/interop only ($(command -v "${pm}")) — install Linux ${pm}"
      REINSTALL_LAST_REASON="${pm} is Windows/interop only"
    else
      log_warn "reinstall skip — '${pm}' not installed (need for ${rel})"
      REINSTALL_LAST_REASON="${pm} not installed"
    fi
    return 2
  }

  run_cmd="${cmd}"
  if [[ "${run_cmd}" == "${pm}" || "${run_cmd}" == "${pm} "* ]]; then
    run_cmd="${pmbin}${run_cmd#"${pm}"}"
  fi

  if [[ "${LINUXBKUP_DRY_RUN:-0}" -eq 1 ]]; then
    ui_kv "${rel}" "would run: ${run_cmd}"
    REINSTALL_LAST_REASON="dry-run"
    return 0
  fi

  mapfile -t env_args < <(reinstall_child_env_args)
  log_file="$(mktemp "${TMPDIR:-/tmp}/linuxbkup-reinstall.XXXXXX.log")"
  REINSTALL_LAST_LOG="${log_file}"

  log_info "reinstall ${rel} via ${pmbin}: ${run_cmd}"
  if declare -F linuxbkup_op_begin >/dev/null 2>&1; then
    # can_skip=1: Ctrl+C menu offers s/c for this project (phase 11 parity)
    linuxbkup_op_begin "reinstall-${pm}" "${dir}" 1 1
  fi
  # Soft-quit: interrupt menu q stops this batch, not the whole restore
  LINUXBKUP_INTERRUPT_SOFT_QUIT=1
  export LINUXBKUP_INTERRUPT_SOFT_QUIT
  local _had_e=0
  [[ $- == *e* ]] && _had_e=1
  set +e
  if [[ "${quiet}" -eq 1 ]]; then
    if declare -F linuxbkup_without_monitor >/dev/null 2>&1; then
      linuxbkup_without_monitor env "${env_args[@]}" \
        bash -c "cd \"${dir}\" && ${run_cmd}" >"${log_file}" 2>&1
    else
      env "${env_args[@]}" bash -c "cd \"${dir}\" && ${run_cmd}" >"${log_file}" 2>&1
    fi
    rc=$?
  else
    if declare -F linuxbkup_without_monitor >/dev/null 2>&1; then
      linuxbkup_without_monitor env "${env_args[@]}" \
        bash -c "cd \"${dir}\" && ${run_cmd}" 2>&1 | tee "${log_file}"
    else
      env "${env_args[@]}" bash -c "cd \"${dir}\" && ${run_cmd}" 2>&1 | tee "${log_file}"
    fi
    rc=${PIPESTATUS[0]}
  fi
  [[ "${_had_e}" -eq 1 ]] && set -e
  if declare -F linuxbkup_op_end >/dev/null 2>&1; then
    linuxbkup_op_end
  fi

  if [[ "${rc}" -eq 0 ]]; then
    log_ok "reinstalled ${rel}"
    REINSTALL_LAST_RC=0
    REINSTALL_LAST_REASON=""
    [[ "${quiet}" -eq 1 ]] && rm -f "${log_file}" && REINSTALL_LAST_LOG=""
    return 0
  fi

  # Soft-quit already applied in interrupt_apply (RESULT=quit, no exit 130)
  if [[ "${LINUXBKUP_INTERRUPT_RESULT:-}" == "quit" ]]; then
    REINSTALL_LAST_RC="${rc}"
    REINSTALL_LAST_REASON="interrupted (quit)"
    REINSTALL_INTERRUPT_QUIT=1
    return 1
  fi

  local _int_pending=0
  if [[ "${LINUXBKUP_WAS_INTERRUPTED:-0}" -eq 1 ]]; then
    _int_pending=1
  elif declare -F linuxbkup_interrupt_pending >/dev/null 2>&1 && linuxbkup_interrupt_pending; then
    _int_pending=1
  fi
  if [[ "${_int_pending}" -eq 1 ]]; then
    LINUXBKUP_WAS_INTERRUPTED=1
    if declare -F linuxbkup_interrupt_resolve >/dev/null 2>&1; then
      linuxbkup_interrupt_resolve
    else
      LINUXBKUP_INTERRUPT_RESULT="${LINUXBKUP_INTERRUPT_RESULT:-skip}"
    fi
    case "${LINUXBKUP_INTERRUPT_RESULT}" in
      retry)
        reinstall_run_one "${home}" "${rel}" "${pm}" "${cmd}"
        return $?
        ;;
      skip)
        if declare -F linuxbkup_interrupt_arm >/dev/null 2>&1; then
          linuxbkup_interrupt_arm
        fi
        REINSTALL_LAST_RC="${rc}"
        REINSTALL_LAST_REASON="interrupted (skip)"
        return 2
        ;;
      continue)
        if declare -F linuxbkup_interrupt_arm >/dev/null 2>&1; then
          linuxbkup_interrupt_arm
        fi
        REINSTALL_LAST_RC="${rc}"
        REINSTALL_LAST_REASON="interrupted (continue)"
        return 2
        ;;
      quit)
        REINSTALL_LAST_RC="${rc}"
        REINSTALL_LAST_REASON="interrupted (quit)"
        REINSTALL_INTERRUPT_QUIT=1
        return 1
        ;;
      *)
        REINSTALL_LAST_RC="${rc}"
        REINSTALL_LAST_REASON="interrupted (quit)"
        REINSTALL_INTERRUPT_QUIT=1
        return 1
        ;;
    esac
  fi

  REINSTALL_LAST_RC="${rc}"
  REINSTALL_LAST_REASON="$(reinstall_classify_fail "${log_file}" "${dir}")"
  [[ -n "${REINSTALL_LAST_REASON}" ]] || REINSTALL_LAST_REASON="exit ${rc}"
  log_warn "reinstall failed (${rc}): ${rel} — ${REINSTALL_LAST_REASON}"
  ui_item note "log: ${log_file}"
  if [[ "${REINSTALL_LAST_REASON}" == *"workspace member missing"* ]]; then
    ui_item note "source packages under the workspace were not in the restore tree"
    ui_item note "re-run backup with those paths kept, or restore again with -f"
  fi
  return 1
}
