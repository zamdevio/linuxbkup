# shellcheck shell=bash
# Reinstall batch apply (split from reinstall.sh — R1 + phase 11).
# Nameref rule: always pass the caller's variable *name* — never a local alias.
# q (soft-quit) stops the batch; partial summary printed; logs kept under /tmp.
# Failure-first re-run: [Enter] failed-only · [p] pick again · [q] quit.

REINSTALL_FAIL_PATHS=()
REINSTALL_INTERRUPT_QUIT=0

# Print failed / skipped project lines under list policy.
# Args: label lines... (each "path<TAB>reason")
reinstall_report_lines() {
  local label="$1"
  shift
  local path reason
  local -a lines=()
  local line

  [[ "$#" -gt 0 ]] || return 0
  printf '\n'
  ui_section "${label}"
  for line in "$@"; do
    path="${line%%$'\t'*}"
    reason="${line#*$'\t'}"
    [[ -n "${reason}" ]] || reason="see log"
    lines+=("$(printf '  %s  —  %s' "${path}" "${reason}")")
  done
  printf '%s\n' "${lines[@]}" | constraints_list_apply
  if declare -F constraints_list_footer >/dev/null 2>&1; then
    constraints_list_footer "${label}"
  fi
}

# Run one batch of selected rows.
# Args: home rows_array_name
# Sets globals: _REINSTALL_BATCH_OK/FAIL/SKIP + *_LINES arrays
#               REINSTALL_INTERRUPT_QUIT=1 when user quit mid-batch
reinstall_run_batch() {
  local home="$1"
  local rows_name="$2"
  local -n _batch_rows="${rows_name}"
  local row path pm lock cmd rc reason
  local had_e=0
  local total="${#_batch_rows[@]}"

  _REINSTALL_BATCH_OK=0
  _REINSTALL_BATCH_FAIL=0
  _REINSTALL_BATCH_SKIP=0
  _REINSTALL_BATCH_FAIL_LINES=()
  _REINSTALL_BATCH_SKIP_LINES=()
  REINSTALL_FAIL_PATHS=()
  REINSTALL_INTERRUPT_QUIT=0
  REINSTALL_BATCH_IDX=0
  REINSTALL_BATCH_TOTAL="${total}"

  [[ "${LINUXBKUP_SKIP_REINSTALL:-0}" -eq 1 ]] && return 0
  [[ "${total}" -eq 0 ]] && return 0

  [[ $- == *e* ]] && had_e=1
  for row in "${_batch_rows[@]}"; do
    # Safe boundary before each project (leftover ^C / menu)
    # 0=quit → stop batch · 1/2=continue to this project
    if declare -F reinstall_interrupt_boundary >/dev/null 2>&1; then
      set +e
      reinstall_interrupt_boundary
      _brc=$?
      [[ "${had_e}" -eq 1 ]] && set -e
      if [[ "${_brc}" -eq 0 ]]; then
        REINSTALL_INTERRUPT_QUIT=1
        return 0
      fi
    fi
    REINSTALL_BATCH_IDX=$((REINSTALL_BATCH_IDX + 1))
    IFS=$'\t' read -r path pm lock cmd <<<"${row}" || true
    set +e
    reinstall_run_one "${home}" "${path}" "${pm}" "${cmd}"
    rc=$?
    [[ "${had_e}" -eq 1 ]] && set -e
    reason="${REINSTALL_LAST_REASON:-}"
    if [[ "${REINSTALL_INTERRUPT_QUIT:-0}" -eq 1 || "${reason}" == "interrupted (quit)" ]]; then
      REINSTALL_INTERRUPT_QUIT=1
      _REINSTALL_BATCH_FAIL=$((_REINSTALL_BATCH_FAIL + 1))
      [[ -n "${reason}" ]] || reason="interrupted (quit)"
      _REINSTALL_BATCH_FAIL_LINES+=("${path}"$'\t'"${reason}")
      REINSTALL_FAIL_PATHS+=("${path}")
      return 0
    fi
    case "${rc}" in
      0) _REINSTALL_BATCH_OK=$((_REINSTALL_BATCH_OK + 1)) ;;
      2)
        _REINSTALL_BATCH_SKIP=$((_REINSTALL_BATCH_SKIP + 1))
        [[ -n "${reason}" ]] || reason="skipped"
        _REINSTALL_BATCH_SKIP_LINES+=("${path}"$'\t'"${reason}")
        ;;
      *)
        _REINSTALL_BATCH_FAIL=$((_REINSTALL_BATCH_FAIL + 1))
        [[ -n "${reason}" ]] || reason="exit ${rc}"
        _REINSTALL_BATCH_FAIL_LINES+=("${path}"$'\t'"${reason}")
        REINSTALL_FAIL_PATHS+=("${path}")
        ;;
    esac
  done
  [[ "${had_e}" -eq 1 ]] && set -e
  REINSTALL_BATCH_TOTAL=0
  REINSTALL_BATCH_IDX=0
  return 0
}

# Print OK/Skipped/Failed summary + reports.
# Args: ok fail skip fail_lines_array_name skip_lines_array_name [quit=0|1]
reinstall_summary_print() {
  local ok="$1" fail="$2" skip="$3"
  local fail_name="$4" skip_name="$5"
  local quit="${6:-0}"
  local -n _sum_fail="${fail_name}"
  local -n _sum_skip="${skip_name}"

  ui_section "Reinstall summary"
  ui_kv "OK" "${ok}"
  ui_kv "Skipped" "${skip}"
  ui_kv "Failed" "${fail}"
  if [[ "${#_sum_skip[@]}" -gt 0 ]]; then
    reinstall_report_lines "Skipped projects" "${_sum_skip[@]}"
  fi
  if [[ "${#_sum_fail[@]}" -gt 0 ]]; then
    reinstall_report_lines "Failed projects (skipped — re-run later)" "${_sum_fail[@]}"
  fi
  if [[ "${quit}" -eq 1 ]]; then
    printf '\n'
    ui_item note "Paused — batch interrupted; logs kept under /tmp"
    ui_item note "Re-run to finish remaining projects"
  fi
  if [[ "${skip}" -gt 0 || "${fail}" -gt 0 ]]; then
    printf '\n'
    ui_item note "Re-run only what you need:"
    ui_item note "  linuxbkup -y --reinstall-only <archive|staging>"
    ui_item note "  linuxbkup -a --reinstall-only <archive|staging>   # pick projects"
  fi
}

# Failure-first re-run prompt (TTY only).
# Sets REINSTALL_RERUN=failed|pick|quit
reinstall_rerun_prompt() {
  local fail_n="$1"
  local reply=""

  REINSTALL_RERUN="quit"
  [[ "${fail_n}" -le 0 ]] && return 0
  [[ "${LINUXBKUP_YES:-0}" -eq 1 || ! -t 0 ]] && return 0

  printf '\n'
  ui_section "Failed projects (skipped — re-run later)"
  printf '  [Enter] re-run all failed only   ·  [p] pick again  ·  [q] quit\n'
  read -r -p "> " reply || reply="q"
  case "${reply}" in
    ""|r|R|rerun|retry)
      REINSTALL_RERUN="failed"
      ;;
    p|P|pick)
      REINSTALL_RERUN="pick"
      ;;
    *)
      REINSTALL_RERUN="quit"
      ;;
  esac
}

reinstall_apply() {
  local root="$1"
  local home="${2:-${LINUXBKUP_HOME:-${HOME:-}}}"
  local -a all_rows=() chosen=() retry_rows=()
  local row path pm lock cmd ok=0 fail=0 skip=0
  local round=0

  if [[ "${LINUXBKUP_SKIP_REINSTALL:-0}" -eq 1 ]]; then
    log_info "reinstalls skipped (--skip-reinstall)"
    return 0
  fi

  # shellcheck source=modules/node.sh
  source "${LINUXBKUP_ROOT}/modules/node.sh"

  reinstall_load_node_rows "${root}" all_rows
  if [[ "${#all_rows[@]}" -eq 0 ]]; then
    log_info "no node reinstalls in backup (packages/reinstalls.tsv)"
    return 0
  fi

  ui_kv "Node projects" "${#all_rows[@]}"

  while true; do
    REINSTALL_INTERRUPT_QUIT=0
    if [[ "${round}" -eq 0 ]]; then
      if ! reinstall_select_node all_rows chosen; then
        return 0
      fi
    else
      chosen=()
      for row in "${retry_rows[@]+"${retry_rows[@]}"}"; do
        chosen+=("${row}")
      done
      [[ "${#chosen[@]}" -eq 0 ]] && return 0
      ui_kv "Re-run" "failed only (${#chosen[@]})"
    fi
    if [[ "${#chosen[@]}" -eq 0 ]]; then
      log_info "no projects selected for reinstall"
      return 0
    fi
    if [[ "${round}" -eq 0 ]]; then
      : # picker already prints Selected N/M
    fi
    ui_item note "failures are skipped — full report at the end"

    reinstall_ensure_pms chosen
    reinstall_run_batch "${home}" chosen

    ok=$((_REINSTALL_BATCH_OK))
    fail=$((_REINSTALL_BATCH_FAIL))
    skip=$((_REINSTALL_BATCH_SKIP))

    reinstall_summary_print "${ok}" "${fail}" "${skip}" \
      _REINSTALL_BATCH_FAIL_LINES _REINSTALL_BATCH_SKIP_LINES \
      "${REINSTALL_INTERRUPT_QUIT}"

    if [[ "${REINSTALL_INTERRUPT_QUIT}" -eq 1 ]]; then
      return 0
    fi

    if [[ "${fail}" -gt 0 ]]; then
      REINSTALL_RERUN="quit"
      reinstall_rerun_prompt "${fail}"
      case "${REINSTALL_RERUN}" in
        failed)
          retry_rows=()
          for row in "${all_rows[@]}"; do
            IFS=$'\t' read -r path pm lock cmd <<<"${row}" || true
            local fp
            for fp in "${REINSTALL_FAIL_PATHS[@]+"${REINSTALL_FAIL_PATHS[@]}"}"; do
              if [[ "${path}" == "${fp}" ]]; then
                retry_rows+=("${row}")
                break
              fi
            done
          done
          round=$((round + 1))
          continue
          ;;
        pick)
          round=0
          continue
          ;;
        *)
          return 0
          ;;
      esac
    fi
    return 0
  done
}
