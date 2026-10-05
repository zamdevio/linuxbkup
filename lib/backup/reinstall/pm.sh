# shellcheck shell=bash
# PM resolve / status / recipes / child env (split from reinstall.sh — R1).
# PMs: only Linux-native binaries count. Windows/interop shims under /mnt/* ignored.

# shellcheck source=lib/core/platform/detect.sh
[[ -n "${LINUXBKUP_ROOT:-}" ]] && source "${LINUXBKUP_ROOT}/lib/core/platform/detect.sh"
# shellcheck source=lib/constraints/list.sh
[[ -n "${LINUXBKUP_ROOT:-}" ]] && source "${LINUXBKUP_ROOT}/lib/constraints/list.sh"

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
# Non-interactive: never prompt for downloads (CI / --yes safe).
reinstall_try_corepack() {
  local -a want=("$@")
  local corepack_bin p
  reinstall_pm_resolve node >/dev/null 2>&1 || return 1
  corepack_bin="$(reinstall_pm_resolve corepack)" || return 1
  for p in "${want[@]}"; do
    case "${p}" in
      pnpm|yarn)
        if ! reinstall_pm_resolve "${p}" >/dev/null 2>&1; then
          log_info "trying corepack for ${p}…"
          set +e
          env CI=1 COREPACK_ENABLE_DOWNLOAD_PROMPT=0 COREPACK_ENABLE_STRICT=0 \
            "${corepack_bin}" enable >/dev/null 2>&1
          env CI=1 COREPACK_ENABLE_DOWNLOAD_PROMPT=0 COREPACK_ENABLE_STRICT=0 \
            "${corepack_bin}" prepare "${p}@stable" --activate >/dev/null 2>&1
          set -e
        fi
        ;;
    esac
  done
  return 0
}

# Child env for PM installs: no interactive prompts (corepack/npm/pnpm).
reinstall_child_env_args() {
  printf '%s\n' \
    "CI=1" \
    "COREPACK_ENABLE_DOWNLOAD_PROMPT=0" \
    "COREPACK_ENABLE_STRICT=0" \
    "npm_config_yes=true" \
    "npm_config_fund=false" \
    "npm_config_audit=false"
}

# Last error-ish line from a PM log (for end-of-run report).
reinstall_log_error_line() {
  local log_file="$1"
  [[ -s "${log_file}" ]] || return 0
  # Prefer explicit error tokens, else last non-empty line
  grep -E -i 'ERR_|error[: ]|fatal|failed' "${log_file}" 2>/dev/null | tail -1 \
    || awk 'NF{line=$0} END{print line}' "${log_file}" 2>/dev/null || true
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
