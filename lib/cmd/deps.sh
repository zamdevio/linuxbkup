# shellcheck shell=bash
# Dependency status / install / howto.

linuxbkup_cmd_deps() {
  # shellcheck source=lib/core/context.sh
  source "${LINUXBKUP_ROOT}/lib/core/context.sh"
  # shellcheck source=lib/tools/check.sh
  source "${LINUXBKUP_ROOT}/lib/tools/check.sh"
  # shellcheck source=lib/tools/catalog.sh
  source "${LINUXBKUP_ROOT}/lib/tools/catalog.sh"

  local sub="${1:-status}"
  shift || true

  case "${sub}" in
    -h|--help|help)
      linuxbkup_cmd_help deps
      return 0
      ;;
    status|"")
      _deps_status
      ;;
    install)
      if cmd_want_help "$@"; then
        linuxbkup_cmd_help deps
        return 0
      fi
      _deps_install "$@"
      ;;
    howto|how-to|guide)
      local tool="${1:-}"
      if cmd_want_help "${tool:-help}"; then
        linuxbkup_cmd_help deps
        return 0
      fi
      if [[ -z "${tool}" ]]; then
        log_fatal "Usage: linuxbkup deps howto <tool>"
        linuxbkup_cmd_help deps
        return 2
      fi
      _deps_howto "${tool}"
      ;;
    *)
      log_fatal "Unknown deps subcommand: ${sub}"
      log_info "Try: linuxbkup help deps"
      return 2
      ;;
  esac
}

# Count present/missing across core + optional. Sets DEPS_* globals.
# Present = Linux-native binary (Windows/interop shims do not count).
_deps_count_catalog() {
  local tool
  DEPS_PRESENT=0
  DEPS_MISSING_CORE=0
  DEPS_MISSING_OPT=0
  DEPS_TOTAL=0

  for tool in "${LINUXBKUP_DEPS_CORE[@]}"; do
    DEPS_TOTAL=$((DEPS_TOTAL + 1))
    if tools_resolve "${tool}" >/dev/null 2>&1; then
      DEPS_PRESENT=$((DEPS_PRESENT + 1))
    else
      DEPS_MISSING_CORE=$((DEPS_MISSING_CORE + 1))
    fi
  done
  for tool in "${LINUXBKUP_DEPS_OPTIONAL[@]}"; do
    DEPS_TOTAL=$((DEPS_TOTAL + 1))
    if tools_resolve "${tool}" >/dev/null 2>&1; then
      DEPS_PRESENT=$((DEPS_PRESENT + 1))
    else
      DEPS_MISSING_OPT=$((DEPS_MISSING_OPT + 1))
    fi
  done
  DEPS_MISSING=$((DEPS_MISSING_CORE + DEPS_MISSING_OPT))
}

# Shared top context for every deps print.
# Args: title  [focus_tool]
_deps_banner() {
  local title="$1"
  local focus="${2:-}"
  local status_label pkg

  _deps_count_catalog

  ui_heading "${title}"
  ui_kv "Detected" "$(tools_pkg_family)"
  ui_kv "Installed" "${DEPS_PRESENT}/${DEPS_TOTAL}"
  ui_kv "Missing" "${DEPS_MISSING}  (core ${DEPS_MISSING_CORE} · optional ${DEPS_MISSING_OPT})"

  if [[ -n "${focus}" ]]; then
    if linuxbkup_require_cmd "${focus}"; then
      status_label="installed"
    else
      status_label="missing"
    fi
    case "$(tools_pkg_family)" in
      apt) pkg="$(tools_guide_get "${focus}" "APT" || true)" ;;
      dnf) pkg="$(tools_guide_get "${focus}" "DNF" || true)" ;;
      yum) pkg="$(tools_guide_get "${focus}" "YUM" || tools_guide_get "${focus}" "DNF" || true)" ;;
      pacman) pkg="$(tools_guide_get "${focus}" "PACMAN" || true)" ;;
      apk) pkg="$(tools_guide_get "${focus}" "APK" || true)" ;;
      pkg) pkg="$(tools_guide_get "${focus}" "APK" || tools_guide_get "${focus}" "APT" || true)" ;;
      brew) pkg="$(tools_guide_get "${focus}" "BREW" || true)" ;;
      *) pkg="" ;;
    esac
    ui_kv "Tool" "${focus}"
    ui_kv "Status" "${status_label}"
    [[ -n "${pkg}" ]] && ui_kv "Package" "${pkg}"
  fi
  DEPS_BANNER_SHOWN=1
  printf '\n'
}

# Prefix for PM bootstrap: empty when already root (iSH/Termux often are).
# Prints "sudo " or "".
_deps_sudo_prefix() {
  local euid="${EUID:-$(id -u 2>/dev/null || echo 1000)}"
  if [[ "${euid}" -eq 0 ]]; then
    return 0
  fi
  if command -v sudo >/dev/null 2>&1; then
    printf 'sudo '
  fi
}

# One-command install for a set of tools on the detected package family.
# Args: tool…  → prints command or empty.
_deps_bootstrap_command() {
  local family pkgs=() tool pkg pre
  family="$(tools_pkg_family)"
  pre="$(_deps_sudo_prefix)"
  for tool in "$@"; do
    tools_guide_pkg_how "${tool}"
    pkg="${TOOLS_GUIDE_PKG:-}"
    [[ -n "${pkg}" ]] || pkg="${tool}"
    pkgs+=("${pkg}")
  done
  [[ "${#pkgs[@]}" -gt 0 ]] || return 0
  case "${family}" in
    apt)
      printf '%sapt update && %sapt install -y %s\n' "${pre}" "${pre}" "${pkgs[*]}"
      ;;
    dnf)
      printf '%sdnf install -y %s\n' "${pre}" "${pkgs[*]}"
      ;;
    yum)
      printf '%syum install -y %s\n' "${pre}" "${pkgs[*]}"
      ;;
    pacman)
      printf '%spacman -S --needed --noconfirm %s\n' "${pre}" "${pkgs[*]}"
      ;;
    apk)
      printf '%sapk add %s\n' "${pre}" "${pkgs[*]}"
      ;;
    pkg)
      # Termux — pkg is already user-level; never sudo
      printf 'pkg install -y %s\n' "${pkgs[*]}"
      ;;
    brew)
      printf 'brew install %s\n' "${pkgs[*]}"
      ;;
    *)
      return 0
      ;;
  esac
}

_deps_status() {
  local tool path
  local -a lines=()

  _deps_banner "linuxbkup deps"

  # Core + optional listed with resolved Linux paths (list policy top-10)
  ui_section "Core / optional"
  lines=()
  for tool in "${LINUXBKUP_DEPS_CORE[@]}"; do
    if path="$(tools_resolve "${tool}")"; then
      lines+=("$(printf '  %s✓%s %s  →  %s  (required)' \
        "${UI_GREEN:-}" "${UI_RESET:-}" "${tool}" "${path}")")
    elif command -v "${tool}" >/dev/null 2>&1; then
      lines+=("$(printf '  %s~%s %s  →  %s  — Windows/interop only' \
        "${UI_YELLOW:-}" "${UI_RESET:-}" "${tool}" "$(command -v "${tool}")")")
    else
      lines+=("$(printf '  %s-%s %s  — missing' \
        "${UI_DIM:-}" "${UI_RESET:-}" "${tool}")")
    fi
  done
  for tool in "${LINUXBKUP_DEPS_OPTIONAL[@]}"; do
    if path="$(tools_resolve "${tool}")"; then
      lines+=("$(printf '  %s✓%s %s  →  %s  (optional)' \
        "${UI_GREEN:-}" "${UI_RESET:-}" "${tool}" "${path}")")
    elif command -v "${tool}" >/dev/null 2>&1; then
      lines+=("$(printf '  %s~%s %s  — Windows/interop only, not usable' \
        "${UI_YELLOW:-}" "${UI_RESET:-}" "${tool}")")
    else
      lines+=("$(printf '  %s-%s %s  — missing (optional)' \
        "${UI_DIM:-}" "${UI_RESET:-}" "${tool}")")
    fi
  done
  if [[ "${#lines[@]}" -gt 0 ]]; then
    printf '%s\n' "${lines[@]}" | constraints_list_apply
    if declare -F constraints_list_footer >/dev/null 2>&1; then
      constraints_list_footer "tool(s)"
    fi
  fi

  local has_extra=0
  local _cat_all
  _cat_all="$(mktemp "${TMPDIR:-/tmp}/linuxbkup-tools.XXXXXX")" || return 0
  tools_catalog_all >"${_cat_all}" || true
  while IFS= read -r tool; do
    [[ "$(tools_dep_tier "${tool}")" == "extra" ]] || continue
    has_extra=1
    break
  done <"${_cat_all}"

  if [[ "${has_extra}" -eq 1 ]]; then
    printf '\n'
    ui_section "Other guides"
    lines=()
    while IFS= read -r tool; do
      [[ "$(tools_dep_tier "${tool}")" == "extra" ]] || continue
      if path="$(tools_resolve "${tool}")"; then
        lines+=("$(printf '  %s✓%s %s  →  %s' \
          "${UI_GREEN:-}" "${UI_RESET:-}" "${tool}" "${path}")")
      else
        lines+=("$(printf '  %s-%s %s' \
          "${UI_DIM:-}" "${UI_RESET:-}" "${tool}")")
      fi
    done <"${_cat_all}"
    if [[ "${#lines[@]}" -gt 0 ]]; then
      printf '%s\n' "${lines[@]}" | constraints_list_apply
      if declare -F constraints_list_footer >/dev/null 2>&1; then
        constraints_list_footer "tool(s)"
      fi
    fi
  fi
  rm -f "${_cat_all}"

  printf '\n'
  if [[ "${DEPS_MISSING_CORE}" -gt 0 ]]; then
    log_warn "Core tools missing — run: linuxbkup deps install"
    return 1
  fi
  if [[ "${DEPS_MISSING_OPT}" -gt 0 ]]; then
    log_info "Optional missing — run: linuxbkup deps install all   or   linuxbkup deps install <tool>"
  fi
  log_ok "deps status complete"
  return 0
}

_deps_howto() {
  local tool="$1"
  _deps_banner "linuxbkup deps howto" "${tool}"
  # tools_print_howto already prints Detected/Package — use a lean body here
  tools_print_howto_body "${tool}"
}

_deps_install() {
  local -a requested=()
  local -a to_install=()
  local -a already=()
  local mode="core" # core | all | named
  local tool how

  while [[ $# -gt 0 ]]; do
    case "$1" in
      all|--all)
        mode="all"
        shift
        ;;
      -*)
        log_fatal "Unknown option for deps install: $1"
        return 2
        ;;
      *)
        mode="named"
        requested+=("$1")
        shift
        ;;
    esac
  done

  # Resolve candidate names first (before any install messaging)
  local -a candidates=()
  case "${mode}" in
    core)
      candidates=("${LINUXBKUP_DEPS_CORE[@]}")
      ;;
    all)
      candidates=("${LINUXBKUP_DEPS_CORE[@]}" "${LINUXBKUP_DEPS_OPTIONAL[@]}")
      ;;
    named)
      candidates=("${requested[@]}")
      ;;
  esac

  # Check each tool BEFORE planning installs
  for tool in "${candidates[@]+"${candidates[@]}"}"; do
    if linuxbkup_require_cmd "${tool}"; then
      already+=("${tool}")
    else
      to_install+=("${tool}")
    fi
  done

  if [[ "${mode}" == "named" && "${#requested[@]}" -eq 1 ]]; then
    _deps_banner "linuxbkup deps install" "${requested[0]}"
  else
    _deps_banner "linuxbkup deps install"
    ui_kv "Scope" "${mode}"
    printf '\n'
  fi

  if [[ "${#already[@]}" -gt 0 ]]; then
    ui_section "Already installed (skip)"
    for tool in "${already[@]}"; do
      ui_item ok "${tool}"
    done
    printf '\n'
  fi

  if [[ "${#to_install[@]}" -eq 0 ]]; then
    log_ok "Nothing to install — requested tools already present"
    if [[ "${mode}" == "core" ]]; then
      ui_item note "Tip: linuxbkup deps install all   (also cover optional)"
    fi
    return 0
  fi

  ui_section "Need install"
  for tool in "${to_install[@]}"; do
    how="$(tools_install_command "${tool}")"
    if [[ -n "${how}" ]]; then
      ui_item warn "${tool}: ${how}"
    else
      ui_item warn "${tool}: no HOW_* for $(tools_pkg_family)"
    fi
  done
  printf '\n'

  # Phase 13 D2 — one-command bootstrap for the whole missing set
  local boot="" failed=0
  if [[ "${#to_install[@]}" -gt 1 ]]; then
    boot="$(_deps_bootstrap_command "${to_install[@]}")"
    if [[ -n "${boot}" ]]; then
      ui_section "Bootstrap (one command)"
      ui_item note "${boot}"
      ui_item note "-y runs this non-interactively; TTY confirms first"
      printf '\n'
      if [[ "${LINUXBKUP_YES:-0}" -eq 1 ]] || safety_confirm "Run bootstrap for ${#to_install[@]} tool(s)?" "y"; then
        if [[ "${LINUXBKUP_DRY_RUN:-0}" -eq 1 ]]; then
          log_info "dry-run — not executing bootstrap"
        else
          log_info "running: ${boot}"
          if bash -lc "${boot}"; then
            local _t
            for _t in "${to_install[@]}"; do
              if tools_resolve "${_t}" >/dev/null 2>&1; then
                log_ok "${_t} → $(tools_resolve "${_t}")"
              else
                failed=1
                log_warn "${_t} still missing after bootstrap"
              fi
            done
            if [[ "${failed}" -eq 0 ]]; then
              log_ok "deps bootstrap complete"
              return 0
            fi
            log_warn "bootstrap left tools missing — falling back to per-tool install"
          else
            log_warn "bootstrap command failed — falling back to per-tool install"
          fi
        fi
      else
        log_skip "bootstrap cancelled — falling back to per-tool install"
      fi
    fi
  fi

  for tool in "${to_install[@]}"; do
    # Re-check immediately before each install (race / prior step)
    if linuxbkup_require_cmd "${tool}"; then
      log_skip "${tool} already installed — skipping"
      continue
    fi
    if ! tools_install_one "${tool}"; then
      failed=1
    fi
    printf '\n'
  done

  if [[ "${failed}" -eq 1 ]]; then
    log_warn "One or more installs did not complete cleanly"
    return 1
  fi
  log_ok "deps install complete"
  return 0
}
