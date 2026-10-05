# shellcheck shell=bash
# reinstall_run_one — one project install (split from run.sh for size budget).
# Ctrl+C menu: r=retry · s=skip · c=continue (partial kept) · q=quit batch.
# Soft-quit: q stops the batch; never exit 130 the whole restore process.
# Interrupt-proof: pending check before work + around PM spawn; workspace
# checks run under op_begin so a ^C lands on the menu, not mid-read.

REINSTALL_LAST_RC=0
REINSTALL_LAST_REASON=""
REINSTALL_LAST_LOG=""
REINSTALL_INTERRUPT_QUIT=0
REINSTALL_BATCH_IDX=0
REINSTALL_BATCH_TOTAL=0

# Resolve any pending interrupt at a safe boundary.
# Returns:
#   2 = nothing pending (safe to proceed)
#   1 = handled (retry/skip/continue applied — caller decides next)
#   0 = quit / soft-quit (REINSTALL_INTERRUPT_QUIT=1)
reinstall_interrupt_boundary() {
  local had_e=0
  REINSTALL_LAST_RC=0
  REINSTALL_LAST_REASON=""
  if [[ "${REINSTALL_INTERRUPT_QUIT:-0}" -eq 1 || "${LINUXBKUP_INTERRUPT_RESULT:-}" == "quit" ]]; then
    REINSTALL_INTERRUPT_QUIT=1
    return 0
  fi
  if ! declare -F linuxbkup_interrupt_pending >/dev/null 2>&1; then
    return 2
  fi
  if ! linuxbkup_interrupt_pending; then
    return 2
  fi
  [[ $- == *e* ]] && had_e=1
  set +e
  linuxbkup_interrupt_resolve
  [[ "${had_e}" -eq 1 ]] && set -e
  case "${LINUXBKUP_INTERRUPT_RESULT:-}" in
    quit)
      REINSTALL_INTERRUPT_QUIT=1
      REINSTALL_LAST_REASON="interrupted (quit)"
      return 0
      ;;
    retry)
      if declare -F linuxbkup_interrupt_arm >/dev/null 2>&1; then
        linuxbkup_interrupt_arm
      fi
      return 1
      ;;
    skip|continue)
      if declare -F linuxbkup_interrupt_arm >/dev/null 2>&1; then
        linuxbkup_interrupt_arm
      fi
      return 1
      ;;
    *)
      return 2
      ;;
  esac
}

reinstall_run_one() {
  local home="$1" rel="$2" pm="$3" cmd="$4"
  local dir="${home}/${rel}"
  local rc=0
  local pmbin="" run_cmd="" log_file="" label=""
  local quiet=1
  local -a env_args=()

  REINSTALL_LAST_RC=0
  REINSTALL_LAST_REASON=""
  REINSTALL_LAST_LOG=""

  if [[ "${LINUXBKUP_VERBOSE:-0}" -eq 1 || "${LINUXBKUP_DEBUG:-0}" -eq 1 ]]; then
    quiet=0
  fi
  label="${rel}"
  if [[ "${REINSTALL_BATCH_TOTAL:-0}" -gt 0 ]]; then
    label="[${REINSTALL_BATCH_IDX:-?}/${REINSTALL_BATCH_TOTAL}] ${rel}"
  fi

  # Safe boundary: leftover ^C from previous project / menu
  # 0=quit · 1=handled (skip/retry leftover) · 2=nothing pending
  local _brc=0 _had_e_start=0
  [[ $- == *e* ]] && _had_e_start=1
  set +e
  reinstall_interrupt_boundary
  _brc=$?
  [[ "${_had_e_start}" -eq 1 ]] && set -e
  case "${_brc}" in
    0) return 1 ;;
    1)
      if [[ "${REINSTALL_INTERRUPT_QUIT:-0}" -eq 1 ]]; then
        return 1
      fi
      ;;
    *) ;;
  esac

  if [[ ! -d "${dir}" ]]; then
    log_warn "reinstall skip — missing ${dir}"
    REINSTALL_LAST_REASON="missing ${rel} (target home has no such project dir)"
    return 2
  fi
  if [[ ! -f "${dir}/package.json" ]]; then
    log_warn "reinstall skip — no package.json in ${rel}"
    REINSTALL_LAST_REASON="no package.json"
    return 2
  fi

  # Workspace roots: members are source in the SAME tree (pnpm-workspace / workspaces).
  # Missing members = sources not in target home → need full restore, not reinstall-only.
  if [[ "${pm}" == "pnpm" || "${pm}" == "npm" ]]; then
    local -a wmiss=()
    if declare -F linuxbkup_interrupt_disarm >/dev/null 2>&1; then
      linuxbkup_interrupt_disarm
    fi
    mapfile -t wmiss < <(reinstall_workspace_missing "${dir}" || true)
    if declare -F linuxbkup_interrupt_arm >/dev/null 2>&1; then
      linuxbkup_interrupt_arm
    fi
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
          log_warn "workspace member(s) missing from target home: ${real_miss[*]}"
          REINSTALL_LAST_REASON="workspace sources missing: ${real_miss[*]}"
          ui_item note "these are source packages in the same workspace tree (not node_modules)"
          ui_item note "run a full restore first so home/ sources land, then --reinstall-only"
        fi
        if [[ "${#pat_miss[@]}" -gt 0 ]]; then
          log_warn "workspace glob matched no dir: ${pat_miss[*]}"
          REINSTALL_LAST_REASON="${REINSTALL_LAST_REASON:+${REINSTALL_LAST_REASON}; }workspace glob empty: ${pat_miss[*]}"
          ui_item note "check backup classification — workspace sources must be kept"
        fi
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

  # Absolute Linux binary + non-interactive PM flags (pnpm allow-all-builds)
  run_cmd="${cmd}"
  if [[ "${run_cmd}" == "${pm}" || "${run_cmd}" == "${pm} "* ]]; then
    run_cmd="${pmbin}${run_cmd#"${pm}"}"
  fi
  if declare -F reinstall_pm_install_cmd >/dev/null 2>&1; then
    # Re-apply flags after binary rewrite (keep pmbin prefix)
    case "${pm}" in
      pnpm)
        if [[ "${run_cmd}" != *dangerouslyAllowAllBuilds* ]]; then
          run_cmd="${run_cmd} --config.dangerouslyAllowAllBuilds=true"
        fi
        ;;
    esac
  fi

  if [[ "${LINUXBKUP_DRY_RUN:-0}" -eq 1 ]]; then
    ui_kv "${rel}" "would run: ${run_cmd}"
    REINSTALL_LAST_REASON="dry-run"
    return 0
  fi

  mapfile -t env_args < <(reinstall_child_env_args)
  log_file="$(mktemp "${TMPDIR:-/tmp}/linuxbkup-reinstall.XXXXXX.log")"
  REINSTALL_LAST_LOG="${log_file}"

  if [[ "${quiet}" -eq 1 ]]; then
    log_verbose "reinstall ${label} via ${pmbin}: ${run_cmd}"
    log_info "reinstall ${label}"
  else
    log_info "reinstall ${label} via ${pmbin}: ${run_cmd}"
  fi
  if declare -F linuxbkup_op_begin >/dev/null 2>&1; then
    # can_skip=1: Ctrl+C menu offers s/c for this project (phase 11 parity)
    linuxbkup_op_begin "reinstall-${pm}" "${dir}" 1 1
  fi
  # Soft-quit: interrupt menu q stops this batch, not the whole restore
  LINUXBKUP_INTERRUPT_SOFT_QUIT=1
  export LINUXBKUP_INTERRUPT_SOFT_QUIT

  # Re-arm after workspace check disarm window
  if declare -F linuxbkup_interrupt_arm >/dev/null 2>&1; then
    linuxbkup_interrupt_arm
  fi

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

  # Soft-quit already applied in interrupt_apply (RESULT=quit, no exit 130)
  if [[ "${LINUXBKUP_INTERRUPT_RESULT:-}" == "quit" ]]; then
    REINSTALL_LAST_RC="${rc}"
    REINSTALL_LAST_REASON="interrupted (quit)"
    REINSTALL_INTERRUPT_QUIT=1
    return 1
  fi

  if [[ "${rc}" -eq 0 ]]; then
    if [[ "${quiet}" -eq 1 ]]; then
      log_verbose "ok ${rel}"
    else
      log_ok "reinstalled ${rel}"
    fi
    REINSTALL_LAST_RC=0
    REINSTALL_LAST_REASON=""
    [[ "${quiet}" -eq 1 ]] && rm -f "${log_file}" && REINSTALL_LAST_LOG=""
    return 0
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
  if [[ "${REINSTALL_LAST_REASON}" == *"workspace member missing"* || "${REINSTALL_LAST_REASON}" == *"workspace sources missing"* ]]; then
    ui_item note "workspace source packages under the tree were not in the target home"
    ui_item note "run a full restore (copy home) first, then --reinstall-only"
  fi
  return 1
}
