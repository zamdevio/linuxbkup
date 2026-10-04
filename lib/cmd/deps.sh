# shellcheck shell=bash
# Dependency status / install / howto.

wslbkup_cmd_deps() {
  # shellcheck source=lib/core/context.sh
  source "${WSLBKUP_ROOT}/lib/core/context.sh"
  # shellcheck source=lib/tools/check.sh
  source "${WSLBKUP_ROOT}/lib/tools/check.sh"
  # shellcheck source=lib/tools/catalog.sh
  source "${WSLBKUP_ROOT}/lib/tools/catalog.sh"

  local sub="${1:-status}"
  shift || true

  case "${sub}" in
    -h|--help|help)
      wslbkup_cmd_help deps
      return 0
      ;;
    status|"")
      _deps_status
      ;;
    install)
      if cmd_want_help "$@"; then
        wslbkup_cmd_help deps
        return 0
      fi
      _deps_install "$@"
      ;;
    howto|how-to|guide)
      local tool="${1:-}"
      if cmd_want_help "${tool:-help}"; then
        wslbkup_cmd_help deps
        return 0
      fi
      if [[ -z "${tool}" ]]; then
        log_fatal "Usage: wslbkup deps howto <tool>"
        wslbkup_cmd_help deps
        return 2
      fi
      _deps_howto "${tool}"
      ;;
    *)
      log_fatal "Unknown deps subcommand: ${sub}"
      log_info "Try: wslbkup help deps"
      return 2
      ;;
  esac
}

# Count present/missing across core + optional. Sets DEPS_* globals.
_deps_count_catalog() {
  local tool
  DEPS_PRESENT=0
  DEPS_MISSING_CORE=0
  DEPS_MISSING_OPT=0
  DEPS_TOTAL=0

  for tool in "${WSLBKUP_DEPS_CORE[@]}"; do
    DEPS_TOTAL=$((DEPS_TOTAL + 1))
    if wslbkup_require_cmd "${tool}"; then
      DEPS_PRESENT=$((DEPS_PRESENT + 1))
    else
      DEPS_MISSING_CORE=$((DEPS_MISSING_CORE + 1))
    fi
  done
  for tool in "${WSLBKUP_DEPS_OPTIONAL[@]}"; do
    DEPS_TOTAL=$((DEPS_TOTAL + 1))
    if wslbkup_require_cmd "${tool}"; then
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
    if wslbkup_require_cmd "${focus}"; then
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

_deps_status() {
  local tool

  _deps_banner "wslbkup deps"

  ui_section "Core (needed for backup/restore)"
  for tool in "${WSLBKUP_DEPS_CORE[@]}"; do
    if wslbkup_require_cmd "${tool}"; then
      ui_item ok "${tool}"
    else
      ui_item warn "${tool}  — missing"
    fi
  done

  printf '\n'
  ui_section "Optional"
  for tool in "${WSLBKUP_DEPS_OPTIONAL[@]}"; do
    if wslbkup_require_cmd "${tool}"; then
      ui_item ok "${tool}"
    else
      ui_item off "${tool}  — missing"
    fi
  done

  local has_extra=0
  while IFS= read -r tool; do
    [[ "$(tools_dep_tier "${tool}")" == "extra" ]] || continue
    has_extra=1
    break
  done < <(tools_catalog_all)

  if [[ "${has_extra}" -eq 1 ]]; then
    printf '\n'
    ui_section "Other guides"
    while IFS= read -r tool; do
      [[ "$(tools_dep_tier "${tool}")" == "extra" ]] || continue
      if wslbkup_require_cmd "${tool}"; then
        ui_item ok "${tool}"
      else
        ui_item off "${tool}"
      fi
    done < <(tools_catalog_all)
  fi

  printf '\n'
  if [[ "${DEPS_MISSING_CORE}" -gt 0 ]]; then
    log_warn "Core tools missing — run: wslbkup deps install"
    return 1
  fi
  if [[ "${DEPS_MISSING_OPT}" -gt 0 ]]; then
    log_info "Optional missing — run: wslbkup deps install all   or   wslbkup deps install <tool>"
  fi
  log_ok "deps status complete"
  return 0
}

_deps_howto() {
  local tool="$1"
  _deps_banner "wslbkup deps howto" "${tool}"
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
      candidates=("${WSLBKUP_DEPS_CORE[@]}")
      ;;
    all)
      candidates=("${WSLBKUP_DEPS_CORE[@]}" "${WSLBKUP_DEPS_OPTIONAL[@]}")
      ;;
    named)
      candidates=("${requested[@]}")
      ;;
  esac

  # Check each tool BEFORE planning installs
  for tool in "${candidates[@]+"${candidates[@]}"}"; do
    if wslbkup_require_cmd "${tool}"; then
      already+=("${tool}")
    else
      to_install+=("${tool}")
    fi
  done

  if [[ "${mode}" == "named" && "${#requested[@]}" -eq 1 ]]; then
    _deps_banner "wslbkup deps install" "${requested[0]}"
  else
    _deps_banner "wslbkup deps install"
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
      ui_item note "Tip: wslbkup deps install all   (also cover optional)"
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

  local failed=0
  for tool in "${to_install[@]}"; do
    # Re-check immediately before each install (race / prior step)
    if wslbkup_require_cmd "${tool}"; then
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
