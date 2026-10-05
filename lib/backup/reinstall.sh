# shellcheck shell=bash
# Restore-time regenerable reinstalls (Node v1; python/go later).

# Load node rows from stage packages/reinstalls.tsv.
# Fills nameref: lines path<TAB>pm<TAB>lockfile<TAB>cmd
reinstall_load_node_rows() {
  local root="$1"
  local -n _rows="$2"
  local tsv="${root}/packages/reinstalls.tsv"
  local kind path pm lock cmd
  local -a raw=()

  _rows=()
  if [[ ! -f "${tsv}" ]]; then
    return 0
  fi
  while IFS=$'\t' read -r kind path pm lock cmd || [[ -n "${kind}" ]]; do
    [[ -z "${kind}" || "${kind}" == \#* ]] && continue
    [[ "${kind}" == "node" ]] || continue
    [[ -n "${path}" && -n "${pm}" && -n "${cmd}" ]] || continue
    raw+=("${path}"$'\t'"${pm}"$'\t'"${lock}"$'\t'"${cmd}")
  done <"${tsv}"

  # Drop noise from older fat manifests
  if declare -F node_filter_reinstall_rows >/dev/null 2>&1; then
    node_filter_reinstall_rows raw _rows
  else
    _rows=("${raw[@]}")
  fi
  return 0
}

# Ensure package managers for the selected rows exist.
# Tries corepack for pnpm/yarn when node is present. Does not curl bun by default.
reinstall_ensure_pms() {
  local -n _rows="$1"
  local path pm lock cmd
  local -A need=() have=()
  local -a missing=() still=()
  local p

  for row in "${_rows[@]+"${_rows[@]}"}"; do
    IFS=$'\t' read -r path pm lock cmd <<<"${row}" || true
    [[ -n "${pm}" ]] && need["${pm}"]=1
  done
  [[ "${#need[@]}" -gt 0 ]] || return 0

  for p in "${!need[@]}"; do
    if command -v "${p}" >/dev/null 2>&1; then
      have["${p}"]=1
    else
      missing+=("${p}")
    fi
  done
  [[ "${#missing[@]}" -gt 0 ]] || return 0

  ui_section "Package managers"
  ui_kv "Needed" "$(printf '%s ' "${!need[@]}")"
  ui_kv "Missing" "${missing[*]}"

  if command -v node >/dev/null 2>&1 && command -v corepack >/dev/null 2>&1; then
    for p in "${missing[@]}"; do
      case "${p}" in
        pnpm|yarn)
          log_info "enabling ${p} via corepack…"
          set +e
          corepack enable >/dev/null 2>&1
          corepack prepare "${p}@stable" --activate >/dev/null 2>&1
          set -e
          ;;
      esac
    done
  elif command -v node >/dev/null 2>&1; then
    log_warn "node present but no corepack — install pnpm/yarn manually or enable corepack"
  fi

  still=()
  for p in "${missing[@]}"; do
    if command -v "${p}" >/dev/null 2>&1; then
      log_ok "${p} ready"
    else
      still+=("${p}")
    fi
  done
  [[ "${#still[@]}" -eq 0 ]] && return 0

  log_warn "still missing: ${still[*]} — those projects will skip"
  for p in "${still[@]}"; do
    case "${p}" in
      npm)
        ui_item note "npm comes with Node — install Node (e.g. apt install nodejs npm), then: linuxbkup --reinstall-only …"
        ;;
      pnpm|yarn)
        ui_item note "${p}: enable with Node — corepack enable && corepack prepare ${p}@stable --activate"
        ;;
      bun)
        ui_item note "bun: https://bun.sh/docs/installation — then: linuxbkup --reinstall-only …"
        ;;
      *)
        ui_item note "install '${p}', then re-run with --reinstall-only"
        ;;
    esac
  done
  return 0
}

# Pick which projects to reinstall.
reinstall_select_node() {
  local -n _in="$1"
  local -n _out="$2"
  local n i pick path pm lock cmd
  local -A want=()

  _out=()
  n="${#_in[@]}"
  [[ "${n}" -gt 0 ]] || return 0

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
    ""|a|A|all|ALL) ;;
    n|N|none|NONE) want=() ;;
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
reinstall_apply() {
  local root="$1"
  local home="${2:-${LINUXBKUP_HOME:-${HOME:-}}}"
  local -a all_rows=() chosen=()
  local path pm lock cmd ok=0 fail=0 skip=0 rc=0

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
  if ! reinstall_select_node all_rows chosen; then
    return 0
  fi
  if [[ "${#chosen[@]}" -eq 0 ]]; then
    log_info "no projects selected for reinstall"
    return 0
  fi

  reinstall_ensure_pms chosen

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
  if [[ "${skip}" -gt 0 || "${fail}" -gt 0 ]]; then
    ui_item note "After installing missing PMs: linuxbkup --reinstall-only <archive|staging>"
  fi
  return 0
}
