# shellcheck shell=bash
# Restore-time regenerable reinstalls (Node v1; python/go later).

# Load node rows from stage packages/reinstalls.tsv (preferred) or .json stub.
# Fills nameref: lines path<TAB>pm<TAB>lockfile<TAB>cmd
reinstall_load_node_rows() {
  local root="$1"
  local -n _rows="$2"
  local tsv="${root}/packages/reinstalls.tsv"
  local kind path pm lock cmd

  _rows=()
  if [[ -f "${tsv}" ]]; then
    while IFS=$'\t' read -r kind path pm lock cmd || [[ -n "${kind}" ]]; do
      [[ -z "${kind}" || "${kind}" == \#* ]] && continue
      [[ "${kind}" == "node" ]] || continue
      [[ -n "${path}" && -n "${pm}" && -n "${cmd}" ]] || continue
      _rows+=("${path}"$'\t'"${pm}"$'\t'"${lock}"$'\t'"${cmd}")
    done <"${tsv}"
    return 0
  fi
  return 0
}

# Pick which projects to reinstall.
# TTY + !yes → multi-select (default all). -y / non-TTY → all.
# Args: nameref in_rows → nameref out_rows (same line format)
# Returns 1 if user aborts.
reinstall_select_node() {
  local -n _in="$1"
  local -n _out="$2"
  local n i pick path pm lock cmd
  local -A want=()

  _out=()
  n="${#_in[@]}"
  [[ "${n}" -gt 0 ]] || return 0

  # -y or non-TTY → all
  if [[ "${LINUXBKUP_YES:-0}" -eq 1 || ! -t 0 ]]; then
    _out=("${_in[@]}")
    return 0
  fi

  # shellcheck source=lib/ask/select.sh
  source "${LINUXBKUP_ROOT}/lib/ask/select.sh"

  ui_section "Node reinstalls"
  ui_item note "node_modules were not backed up — pick projects to regenerate"
  ui_item note "default: all  ·  a=all  ·  n=none  ·  numbers/ranges  ·  Enter=all  ·  q=skip step"
  printf '\n'
  for ((i = 0; i < n; i++)); do
    IFS=$'\t' read -r path pm lock cmd <<<"${_in[i]}" || true
    printf '  [%d] %-6s  %s  (%s)\n' "$((i + 1))" "${pm}" "${path}" "${cmd}"
    want["${i}"]=1
  done
  printf '\n'

  read -r -p "> " pick || pick="q"
  case "${pick}" in
    q|Q|quit)
      log_skip "reinstall step skipped by user"
      return 1
      ;;
    ""|a|A|all|ALL)
      ;;
    n|N|none|NONE)
      want=()
      ;;
    *)
      want=()
      while IFS= read -r i; do
        [[ -z "${i}" ]] && continue
        i=$((i - 1))
        [[ "${i}" -ge 0 && "${i}" -lt "${n}" ]] && want["${i}"]=1
      done < <(ask_parse_selection "${n}" "${pick}")
      ;;
  esac

  for ((i = 0; i < n; i++)); do
    [[ -n "${want[${i}]+x}" ]] || continue
    _out+=("${_in[i]}")
  done
  return 0
}

# Run one project install. Args: dest_home rel_path pm cmd
# Returns 0 ok, 1 fail, 2 skip (missing dir / tool)
reinstall_run_one() {
  local home="$1" rel="$2" pm="$3" cmd="$4"
  local dir="${home}/${rel}"
  local rc=0

  if [[ ! -d "${dir}" ]]; then
    log_warn "reinstall skip — missing ${dir}"
    return 2
  fi
  if [[ ! -f "${dir}/package.json" ]]; then
    log_warn "reinstall skip — no package.json in ${rel}"
    return 2
  fi
  if ! command -v "${pm}" >/dev/null 2>&1; then
    log_warn "reinstall skip — '${pm}' not installed (need for ${rel})"
    ui_item note "Install ${pm}, then re-run restore or: (cd ${dir} && ${cmd})"
    return 2
  fi

  if [[ "${LINUXBKUP_DRY_RUN:-0}" -eq 1 ]]; then
    ui_kv "${rel}" "would run: ${cmd}"
    return 0
  fi

  log_info "reinstall ${rel} via ${pm}: ${cmd}"
  linuxbkup_op_begin "reinstall-${pm}" "${dir}" 0 1
  set +e
  linuxbkup_without_monitor bash -c "cd \"${dir}\" && ${cmd}"
  rc=$?
  set -e
  linuxbkup_op_end

  if [[ "${rc}" -eq 0 ]]; then
    log_ok "reinstalled ${rel}"
    return 0
  fi
  if [[ "${LINUXBKUP_WAS_INTERRUPTED:-0}" -eq 1 ]] || linuxbkup_interrupt_pending; then
    LINUXBKUP_WAS_INTERRUPTED=1
    linuxbkup_interrupt_resolve
    case "${LINUXBKUP_INTERRUPT_RESULT}" in
      retry) reinstall_run_one "${home}" "${rel}" "${pm}" "${cmd}"; return $? ;;
      skip|continue) return 2 ;;
      *) return 1 ;;
    esac
  fi
  log_warn "reinstall failed (${rc}): ${rel}"
  return 1
}

# Apply node reinstalls from archive/stage root into dest_home.
# Returns 0 always for soft failures (per-project); 1 only on hard abort.
reinstall_apply() {
  local root="$1"
  local home="${2:-${LINUXBKUP_HOME:-${HOME:-}}}"
  local -a all_rows=() chosen=()
  local path pm lock cmd ok=0 fail=0 skip=0 rc=0

  if [[ "${LINUXBKUP_SKIP_REINSTALL:-0}" -eq 1 ]]; then
    log_info "reinstalls skipped (--skip-reinstall)"
    return 0
  fi

  reinstall_load_node_rows "${root}" all_rows
  if [[ "${#all_rows[@]}" -eq 0 ]]; then
    log_info "no node reinstalls in backup (packages/reinstalls.tsv)"
    return 0
  fi

  ui_kv "Node projects" "${#all_rows[@]}"
  if ! reinstall_select_node all_rows chosen; then
    return 0
  fi
  if [[ "${#chosen[@]}" -eq 0 ]]; then
    log_info "no projects selected for reinstall"
    return 0
  fi

  for row in "${chosen[@]}"; do
    IFS=$'\t' read -r path pm lock cmd <<<"${row}" || true
    set +e
    reinstall_run_one "${home}" "${path}" "${pm}" "${cmd}"
    rc=$?
    set -e
    case "${rc}" in
      0) ok=$((ok + 1)) ;;
      2) skip=$((skip + 1)) ;;
      *) fail=$((fail + 1)) ;;
    esac
  done

  ui_section "Reinstall summary"
  ui_kv "OK" "${ok}"
  ui_kv "Skipped" "${skip}"
  ui_kv "Failed" "${fail}"
  return 0
}
