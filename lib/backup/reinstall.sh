# shellcheck shell=bash
# Restore-time regenerable reinstalls (Node v1; python/go later).
# Nameref rule: always pass the caller's variable *name* into callees — never a
# local nameref alias (bash circular-name-ref).
# PMs: only Linux-native binaries count. Windows/interop shims under /mnt/* are ignored.

# shellcheck source=lib/core/platform/detect.sh
[[ -n "${LINUXBKUP_ROOT:-}" ]] && source "${LINUXBKUP_ROOT}/lib/core/platform/detect.sh"
# shellcheck source=lib/constraints/list.sh
[[ -n "${LINUXBKUP_ROOT:-}" ]] && source "${LINUXBKUP_ROOT}/lib/constraints/list.sh"

# Load node rows from a reinstalls.tsv file path.
# Args: tsv_path out_array_name
reinstall_load_node_rows_file() {
  local tsv="$1"
  local out_name="$2"
  local -n _load_rows="${out_name}"
  local kind path pm lock cmd
  local -a raw=()

  _load_rows=()
  [[ -f "${tsv}" ]] || return 0
  while IFS=$'\t' read -r kind path pm lock cmd || [[ -n "${kind}" ]]; do
    [[ -z "${kind}" || "${kind}" == \#* ]] && continue
    [[ "${kind}" == "node" ]] || continue
    [[ -n "${path}" && -n "${pm}" && -n "${cmd}" ]] || continue
    raw+=("${path}"$'\t'"${pm}"$'\t'"${lock}"$'\t'"${cmd}")
  done <"${tsv}"

  if ! declare -F node_filter_reinstall_rows >/dev/null 2>&1; then
    # shellcheck source=modules/node.sh
    source "${LINUXBKUP_ROOT}/modules/node.sh"
  fi
  node_filter_reinstall_rows raw "${out_name}"
  return 0
}

# Load from stage/extract root.
# Args: root out_array_name
reinstall_load_node_rows() {
  reinstall_load_node_rows_file "${1}/packages/reinstalls.tsv" "$2"
}

# Peek reinstalls.tsv from staging or archive without full extract.
# Args: backup kind(staging|archive) out_array_name
reinstall_peek_from_backup() {
  local backup="$1"
  local kind="$2"
  local out_name="$3"
  local -n _peek_rows="${out_name}"
  local tmp="" member=""

  _peek_rows=()
  # shellcheck source=modules/node.sh
  source "${LINUXBKUP_ROOT}/modules/node.sh"

  if [[ "${kind}" == "staging" ]]; then
    reinstall_load_node_rows "${backup}" "${out_name}"
    return 0
  fi

  tmp="$(mktemp "${TMPDIR:-/tmp}/linuxbkup-reinst-peek.XXXXXX")"
  for member in packages/reinstalls.tsv ./packages/reinstalls.tsv; do
    if zstd -dcq "${backup}" 2>/dev/null \
      | tar --warning=no-timestamp -xO "${member}" >"${tmp}" 2>/dev/null \
      && [[ -s "${tmp}" ]]; then
      reinstall_load_node_rows_file "${tmp}" "${out_name}"
      rm -f "${tmp}"
      return 0
    fi
    : >"${tmp}"
  done
  rm -f "${tmp}"
  return 0
}

# Unique PMs + counts. Args: rows_array_name → prints pm<TAB>count
reinstall_pm_counts() {
  local -n _cnt_rows="$1"
  local path pm lock cmd
  local -A cnt=()
  for row in "${_cnt_rows[@]+"${_cnt_rows[@]}"}"; do
    IFS=$'\t' read -r path pm lock cmd <<<"${row}" || true
    [[ -n "${pm}" ]] || continue
    cnt["${pm}"]=$((${cnt["${pm}"]:-0} + 1))
  done
  for pm in "${!cnt[@]}"; do
    printf '%s\t%s\n' "${pm}" "${cnt[${pm}]}"
  done | sort
}

# Resolve a Linux-native binary path for a PM name.
# Prints path; returns 1 if missing or only a Windows/interop shim exists.
reinstall_pm_resolve() {
  local pm="$1"
  declare -F platform_linux_command >/dev/null 2>&1 \
    && platform_linux_command "${pm}"
}

# Print one PM status line: status  pm  path  count
# status: ready|missing|interop
# Args: pm count
reinstall_pm_status_line() {
  local pm="$1"
  local count="${2:-}"
  local path="" kind="missing"

  if path="$(reinstall_pm_resolve "${pm}")"; then
    kind="ready"
  elif command -v "${pm}" >/dev/null 2>&1; then
    kind="interop"
    path="$(command -v "${pm}" 2>/dev/null || true)"
  fi
  printf '%s\t%s\t%s\t%s\n' "${kind}" "${pm}" "${path}" "${count}"
}

# Print install recipe for one Node PM (generic; no host names).
reinstall_pm_recipe() {
  local pm="$1"
  case "${pm}" in
    npm)
      ui_item note "npm — install Node.js (includes npm):"
      ui_item note "  sudo apt update && sudo apt install -y nodejs npm"
      ui_item note "  # or: https://nodejs.org / mise / nvm — then re-check"
      ;;
    pnpm)
      ui_item note "pnpm — with Node already installed:"
      ui_item note "  corepack enable && corepack prepare pnpm@stable --activate"
      ui_item note "  # or: npm install -g pnpm"
      ;;
    yarn)
      ui_item note "yarn — with Node already installed:"
      ui_item note "  corepack enable && corepack prepare yarn@stable --activate"
      ;;
    bun)
      ui_item note "bun — official installer:"
      ui_item note "  curl -fsSL https://bun.sh/install | bash"
      ui_item note "  # then restart shell / ensure ~/.bun/bin on PATH"
      ;;
    *)
      ui_item note "install '${pm}' with your distro or upstream docs"
      ;;
  esac
}

# Try corepack for pnpm/yarn using Linux-native node/corepack only.
reinstall_try_corepack() {
  local -a want=("$@")
  local node_bin corepack_bin p
  node_bin="$(reinstall_pm_resolve node)" || return 1
  corepack_bin="$(reinstall_pm_resolve corepack)" || return 1
  for p in "${want[@]}"; do
    case "${p}" in
      pnpm|yarn)
        if ! reinstall_pm_resolve "${p}" >/dev/null 2>&1; then
          log_info "trying corepack for ${p}…"
          set +e
          "${corepack_bin}" enable >/dev/null 2>&1
          "${corepack_bin}" prepare "${p}@stable" --activate >/dev/null 2>&1
          set -e
        fi
        ;;
    esac
  done
  return 0
}

# List missing PMs (Linux-native only) from a set of pm names (args).
reinstall_missing_pms() {
  local p
  for p in "$@"; do
    reinstall_pm_resolve "${p}" >/dev/null 2>&1 || printf '%s\n' "${p}"
  done
}

# Render PM status list under listing policy (top-N default 10).
# Args: rows_array_name
reinstall_pm_status_list() {
  local rows_name="$1"
  local -n _st_rows="${rows_name}"
  local kind pm path count
  local -a ready_lines=() miss_lines=() interop_lines=()
  local -a out_lines=()
  local line

  for line in "${_st_rows[@]+"${_st_rows[@]}"}"; do
    IFS=$'\t' read -r kind pm path count <<<"${line}" || true
    case "${kind}" in
      ready)
        out_lines+=("$(printf '  %s✓%s %-8s %s  (%s)' \
          "${UI_GREEN:-}" "${UI_RESET:-}" "${pm}" "${path}" "${count:-?}")")
        ;;
      interop)
        out_lines+=("$(printf '  %s~%s %-8s %s  — Windows/interop only, not usable' \
          "${UI_YELLOW:-}" "${UI_RESET:-}" "${pm}" "${path}")")
        ;;
      missing)
        out_lines+=("$(printf '  %s-%s %-8s missing — install Linux package' \
          "${UI_DIM:-}" "${UI_RESET:-}" "${pm}")")
        ;;
    esac
  done

  if [[ "${#out_lines[@]}" -eq 0 ]]; then
    return 0
  fi
  printf '%s\n' "${out_lines[@]}" | constraints_list_apply
  if declare -F constraints_list_footer >/dev/null 2>&1; then
    constraints_list_footer "PM(s)"
  fi
}

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

  reinstall_peek_from_backup "${backup}" "${kind}" rows
  if [[ "${#rows[@]}" -eq 0 ]]; then
    log_verbose "reinstall preflight: no packages/reinstalls.tsv (or empty after filter)"
    return 0
  fi

  ui_section "Reinstall preflight"
  ui_item note "Checked packages/reinstalls.tsv without full archive extract"
  ui_kv "Node projects" "${#rows[@]}"

  while IFS=$'\t' read -r pm count; do
    [[ -z "${pm}" ]] && continue
    pms+=("${pm}")
    status+=("$(reinstall_pm_status_line "${pm}" "${count}")")
    case "${pm}" in
      npm|pnpm|yarn) need_node=1 ;;
    esac
  done < <(reinstall_pm_counts rows)

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

  mapfile -t missing < <(reinstall_missing_pms "${pms[@]}")
  missing_n="${#missing[@]}"
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
  mapfile -t missing < <(reinstall_missing_pms "${pms[@]}")
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
        mapfile -t missing < <(reinstall_missing_pms "${pms[@]}")
        status=()
        for pm in "${pms[@]}"; do
          count="$(reinstall_pm_counts rows | awk -F'\t' -v p="${pm}" '$1==p{print $2}')"
          status+=("$(reinstall_pm_status_line "${pm}" "${count}")")
        done
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

# Late ensure (after project pick) — short tip only; preflight already guided.
# Args: rows_array_name
reinstall_ensure_pms() {
  local rows_name="$1"
  local -n _ens_rows="${rows_name}"
  local path pm lock cmd
  local -A need=()
  local -a missing=()

  for row in "${_ens_rows[@]+"${_ens_rows[@]}"}"; do
    IFS=$'\t' read -r path pm lock cmd <<<"${row}" || true
    [[ -n "${pm}" ]] && need["${pm}"]=1
  done
  mapfile -t missing < <(reinstall_missing_pms "${!need[@]}")
  [[ "${#missing[@]}" -eq 0 ]] && return 0
  reinstall_try_corepack "${missing[@]}" || true
  mapfile -t missing < <(reinstall_missing_pms "${!need[@]}")
  [[ "${#missing[@]}" -eq 0 ]] && return 0
  log_warn "missing PMs for selected projects: ${missing[*]}"
  for pm in "${missing[@]}"; do
    reinstall_pm_recipe "${pm}"
  done
  return 0
}

# Pick which projects to reinstall.
# Interactive under TTY when --ask or neither --yes nor non-TTY.
# -y / non-TTY / no --ask: all projects (safe default).
# Args: in_array_name out_array_name
reinstall_select_node() {
  local in_name="$1"
  local out_name="$2"
  local -n _sel_in="${in_name}"
  local -n _sel_out="${out_name}"
  local n i pick path pm lock cmd
  local -A want=()
  local interactive=0
  local use_fzf=0

  _sel_out=()
  n="${#_sel_in[@]}"
  [[ "${n}" -gt 0 ]] || return 0

  # Interactive when --ask on TTY, or plain TTY without --yes
  if [[ "${LINUXBKUP_YES:-0}" -ne 1 && -t 0 ]]; then
    interactive=1
  fi
  if [[ "${LINUXBKUP_ASK:-0}" -eq 1 && -t 0 ]]; then
    interactive=1
  fi

  if [[ "${interactive}" -ne 1 ]]; then
    _sel_out=("${_sel_in[@]}")
    return 0
  fi

  # shellcheck source=lib/ask/select.sh
  source "${LINUXBKUP_ROOT}/lib/ask/select.sh"
  # shellcheck source=lib/constraints/list.sh
  source "${LINUXBKUP_ROOT}/lib/constraints/list.sh"

  ui_section "Node reinstalls"
  ui_item note "node_modules were not backed up — pick projects to regenerate"
  if [[ "${n}" -gt 10 ]]; then
    ui_item note "listing policy: top ${CONSTRAINTS_LIST_DEFAULT_TOP:-10} of ${n}  ·  -F/--full for all"
  fi
  ui_item note "a=all  ·  n=none  ·  numbers/ranges  ·  f=fzf  ·  Enter=all  ·  q=skip step"
  printf '\n'

  # Build display lines under list policy
  local -a display=()
  for ((i = 0; i < n; i++)); do
    IFS=$'\t' read -r path pm lock cmd <<<"${_sel_in[i]}" || true
    display+=("$(printf '  [%d] %-6s  %s  (%s)' "$((i + 1))" "${pm}" "${path}" "${cmd}")")
    want["${i}"]=1
  done
  printf '%s\n' "${display[@]}" | constraints_list_apply
  if declare -F constraints_list_footer >/dev/null 2>&1; then
    constraints_list_footer "project(s)"
  fi
  printf '\n'

  # fzf path when many projects
  if [[ "${n}" -gt 20 ]] && command -v fzf >/dev/null 2>&1; then
    ui_item note "large list — type f then Enter for fuzzy multi-select"
  fi

  while true; do
    read -r -p "> " pick || pick="q"
    case "${pick}" in
      q|Q|quit)
        log_skip "reinstall step skipped by user"
        return 1
        ;;
      f|F|fzf)
        if command -v fzf >/dev/null 2>&1; then
          use_fzf=1
          break
        fi
        log_warn "fzf not installed — run: linuxbkup deps install fzf"
        continue
        ;;
      ""|a|A|all|ALL)
        break
        ;;
      n|N|none|NONE)
        want=()
        break
        ;;
      *)
        want=()
        while IFS= read -r i; do
          [[ -z "${i}" ]] && continue
          i=$((i - 1))
          [[ "${i}" -ge 0 && "${i}" -lt "${n}" ]] && want["${i}"]=1
        done < <(ask_parse_selection "${n}" "${pick}")
        break
        ;;
    esac
  done

  if [[ "${use_fzf}" -eq 1 ]]; then
    local -a fzf_in=() fzf_out=() fzf_idx=()
    for ((i = 0; i < n; i++)); do
      IFS=$'\t' read -r path pm lock cmd <<<"${_sel_in[i]}" || true
      fzf_in+=("$(printf '%d\t%s\t%s\t%s' "$((i + 1))" "${pm}" "${path}" "${cmd}")")
    done
    mapfile -t fzf_out < <(
      printf '%s\n' "${fzf_in[@]}" | fzf -m \
        --header="TAB select · Enter confirm · Esc abort" \
        --with-nth=2,3,4 --delimiter=$'\t' || true
    )
    want=()
    if [[ "${#fzf_out[@]}" -gt 0 ]]; then
      for i in "${fzf_out[@]}"; do
        fzf_idx+=("${i%%$'\t'*}")
      done
      for i in "${fzf_idx[@]}"; do
        i=$((i - 1))
        [[ "${i}" -ge 0 && "${i}" -lt "${n}" ]] && want["${i}"]=1
      done
    else
      # Esc → all (same as Enter)
      for ((i = 0; i < n; i++)); do want["${i}"]=1; done
    fi
  fi

  for ((i = 0; i < n; i++)); do
    [[ -n "${want[${i}]+x}" ]] || continue
    _sel_out+=("${_sel_in[i]}")
  done
  return 0
}

reinstall_run_one() {
  local home="$1" rel="$2" pm="$3" cmd="$4"
  local dir="${home}/${rel}"
  local rc=0
  local pmbin="" run_cmd=""

  if [[ ! -d "${dir}" ]]; then
    log_warn "reinstall skip — missing ${dir}"
    return 2
  fi
  if [[ ! -f "${dir}/package.json" ]]; then
    log_warn "reinstall skip — no package.json in ${rel}"
    return 2
  fi
  pmbin="$(reinstall_pm_resolve "${pm}")" || {
    if command -v "${pm}" >/dev/null 2>&1; then
      log_warn "reinstall skip — '${pm}' is Windows/interop only ($(command -v "${pm}")) — install Linux ${pm}"
    else
      log_warn "reinstall skip — '${pm}' not installed (need for ${rel})"
    fi
    return 2
  }

  # Prefer absolute Linux binary path in the command
  run_cmd="${cmd}"
  if [[ "${run_cmd}" == "${pm}" || "${run_cmd}" == "${pm} "* ]]; then
    run_cmd="${pmbin}${run_cmd#"${pm}"}"
  fi

  if [[ "${LINUXBKUP_DRY_RUN:-0}" -eq 1 ]]; then
    ui_kv "${rel}" "would run: ${run_cmd}"
    return 0
  fi

  log_info "reinstall ${rel} via ${pmbin}: ${run_cmd}"
  linuxbkup_op_begin "reinstall-${pm}" "${dir}" 0 1
  set +e
  linuxbkup_without_monitor bash -c "cd \"${dir}\" && ${run_cmd}"
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
  ui_kv "Selected" "${#chosen[@]}"

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
    ui_item note "After installing missing PMs: linuxbkup -y --reinstall-only <archive|staging>"
  fi
  return 0
}
