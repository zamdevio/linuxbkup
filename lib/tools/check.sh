# shellcheck shell=bash
# Tool presence checks + platform How-To guides from guides/tools/<name>.guide

# shellcheck source=lib/core/platform/detect.sh
[[ -n "${LINUXBKUP_ROOT:-}" ]] && source "${LINUXBKUP_ROOT}/lib/core/platform/detect.sh"
# shellcheck source=lib/constraints/list.sh
[[ -n "${LINUXBKUP_ROOT:-}" ]] && source "${LINUXBKUP_ROOT}/lib/constraints/list.sh"

tools_guides_dir() {
  printf '%s\n' "${LINUXBKUP_ROOT}/guides/tools"
}

# Linux-native path for a tool (skips Windows/interop shims). Falls back to command -v.
# Phase 13: sha256sum is satisfied by any sha256 provider (shasum/openssl).
tools_resolve() {
  local tool="$1"
  if [[ "${tool}" == "sha256sum" ]] && declare -F compat_sha_tool >/dev/null 2>&1; then
    local sha
    sha="$(compat_sha_tool)"
    if [[ -n "${sha}" ]]; then
      command -v "${sha}" 2>/dev/null && return 0
    fi
  fi
  if declare -F platform_linux_command >/dev/null 2>&1; then
    platform_linux_command "${tool}" && return 0
  fi
  command -v "${tool}" 2>/dev/null
}

# Detect package family for install hints.
# Phase 13 D2: Termux `pkg` before apt; Alpine prefers apk.
tools_pkg_family() {
  if [[ -n "${TERMUX_VERSION:-}" ]] && command -v pkg >/dev/null 2>&1; then
    printf '%s\n' "pkg"
  elif command -v apk >/dev/null 2>&1 \
    && ! command -v apt-get >/dev/null 2>&1 \
    && ! command -v apt >/dev/null 2>&1; then
    printf '%s\n' "apk"
  elif linuxbkup_require_cmd apt-get || linuxbkup_require_cmd apt; then
    printf '%s\n' "apt"
  elif linuxbkup_require_cmd dnf; then
    printf '%s\n' "dnf"
  elif linuxbkup_require_cmd yum; then
    printf '%s\n' "yum"
  elif linuxbkup_require_cmd pacman; then
    printf '%s\n' "pacman"
  elif linuxbkup_require_cmd apk; then
    printf '%s\n' "apk"
  elif linuxbkup_require_cmd brew; then
    printf '%s\n' "brew"
  else
    printf '%s\n' "unknown"
  fi
}

# Read KEY=value from a .guide file (first match).
tools_guide_get() {
  local tool="$1" key="$2"
  local file
  file="$(tools_guides_dir)/${tool}.guide"
  [[ -r "${file}" ]] || return 1
  awk -F= -v k="${key}" '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    $1 == k { sub(/^[^=]*=/, ""); print; exit }
  ' "${file}"
}

tools_guide_exists() {
  [[ -r "$(tools_guides_dir)/$1.guide" ]]
}

# Resolve package name + how-command for current family.
tools_guide_pkg_how() {
  local tool="$1"
  local family
  family="$(tools_pkg_family)"
  TOOLS_GUIDE_PKG=""
  TOOLS_GUIDE_HOW=""
  case "${family}" in
    apt)
      TOOLS_GUIDE_PKG="$(tools_guide_get "${tool}" "APT" || true)"
      TOOLS_GUIDE_HOW="$(tools_guide_get "${tool}" "HOW_APT" || true)"
      ;;
    dnf)
      TOOLS_GUIDE_PKG="$(tools_guide_get "${tool}" "DNF" || true)"
      TOOLS_GUIDE_HOW="$(tools_guide_get "${tool}" "HOW_DNF" || true)"
      ;;
    yum)
      TOOLS_GUIDE_PKG="$(tools_guide_get "${tool}" "YUM" || tools_guide_get "${tool}" "DNF" || true)"
      TOOLS_GUIDE_HOW="$(tools_guide_get "${tool}" "HOW_YUM" || tools_guide_get "${tool}" "HOW_DNF" || true)"
      ;;
    pacman)
      TOOLS_GUIDE_PKG="$(tools_guide_get "${tool}" "PACMAN" || true)"
      TOOLS_GUIDE_HOW="$(tools_guide_get "${tool}" "HOW_PACMAN" || true)"
      ;;
    apk)
      TOOLS_GUIDE_PKG="$(tools_guide_get "${tool}" "APK" || true)"
      TOOLS_GUIDE_HOW="$(tools_guide_get "${tool}" "HOW_APK" || true)"
      ;;
    brew)
      TOOLS_GUIDE_PKG="$(tools_guide_get "${tool}" "BREW" || true)"
      TOOLS_GUIDE_HOW="$(tools_guide_get "${tool}" "HOW_BREW" || true)"
      ;;
  esac
}

# Body of a How-To. When DEPS_BANNER_SHOWN=1, skips Detected/Status/Package (already in banner).
tools_print_howto_body() {
  local tool="$1"
  local summary how note status_label
  local family
  family="$(tools_pkg_family)"

  if tools_resolve "${tool}" >/dev/null 2>&1; then
    status_label="installed"
  else
    status_label="missing"
  fi

  ui_section "How to install: ${tool}"
  if ! tools_guide_exists "${tool}"; then
    ui_item warn "No guide at guides/tools/${tool}.guide"
    ui_item note "Install ${tool} with your distro package manager, then re-run."
    return 0
  fi

  summary="$(tools_guide_get "${tool}" "SUMMARY" || true)"
  [[ -n "${summary}" ]] && ui_item note "${summary}"

  tools_guide_pkg_how "${tool}"
  how="${TOOLS_GUIDE_HOW}"

  if [[ "${DEPS_BANNER_SHOWN:-0}" -ne 1 ]]; then
    ui_kv "Detected" "${family}"
    ui_kv "Status" "${status_label}"
    [[ -n "${TOOLS_GUIDE_PKG}" ]] && ui_kv "Package" "${TOOLS_GUIDE_PKG}"
  fi

  if [[ "${status_label}" == "installed" ]]; then
    printf '\n'
    log_ok "${tool} is already installed — no action needed"
    ui_item ok "${tool}  →  $(tools_resolve "${tool}")"
    note="$(tools_guide_get "${tool}" "NOTE" || true)"
    [[ -n "${note}" ]] && ui_item note "${note}"
    printf '\n'
    return 0
  fi

  if [[ -n "${how}" ]]; then
    printf '\n'
    ui_item note "Run:"
    printf '    %s\n' "${how}"
    ui_item note "Or: linuxbkup deps install ${tool}"
  else
    printf '\n'
    ui_item note "See guides/tools/${tool}.guide for install options on other platforms."
  fi

  note="$(tools_guide_get "${tool}" "NOTE" || true)"
  [[ -n "${note}" ]] && ui_item note "${note}"
  printf '\n'
}

# Standalone How-To (used outside deps banner).
tools_print_howto() {
  tools_print_howto_body "$1"
}

# Check a list of tools. Args: --required t1 t2 --optional o1 o2
# Ready tools listed with resolved Linux paths; list policy truncates >10.
# Returns 1 if any required tool is missing (after printing howtos).
tools_check() {
  local -a required=() optional=()
  local mode="required" t
  local missing_req=0
  local -a ready_lines=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --required) mode="required"; shift ;;
      --optional) mode="optional"; shift ;;
      --) shift; mode="required" ;;
      *)
        if [[ "${mode}" == "optional" ]]; then
          optional+=("$1")
        else
          required+=("$1")
        fi
        shift
        ;;
    esac
  done

  for t in "${required[@]+"${required[@]}"}"; do
    if tools_resolve "${t}" >/dev/null 2>&1; then
      ready_lines+=("$(printf '  %s✓%s %s  →  %s  (required)' \
        "${UI_GREEN:-}" "${UI_RESET:-}" "${t}" "$(tools_resolve "${t}")")")
    elif command -v "${t}" >/dev/null 2>&1; then
      ready_lines+=("$(printf '  %s~%s %s  →  %s  — Windows/interop only' \
        "${UI_YELLOW:-}" "${UI_RESET:-}" "${t}" "$(command -v "${t}")")")
      missing_req=1
    else
      ready_lines+=("$(printf '  %s-%s %s  (required — missing)' \
        "${UI_DIM:-}" "${UI_RESET:-}" "${t}")")
      missing_req=1
    fi
  done
  for t in "${optional[@]+"${optional[@]}"}"; do
    if tools_resolve "${t}" >/dev/null 2>&1; then
      ready_lines+=("$(printf '  %s✓%s %s  →  %s  (optional)' \
        "${UI_GREEN:-}" "${UI_RESET:-}" "${t}" "$(tools_resolve "${t}")")")
    elif command -v "${t}" >/dev/null 2>&1; then
      ready_lines+=("$(printf '  %s~%s %s  — Windows/interop only, not usable' \
        "${UI_YELLOW:-}" "${UI_RESET:-}" "${t}")")
    else
      ready_lines+=("$(printf '  %s-%s %s  (optional — missing)' \
        "${UI_DIM:-}" "${UI_RESET:-}" "${t}")")
    fi
  done

  if [[ "${#ready_lines[@]}" -gt 0 ]]; then
    printf '%s\n' "${ready_lines[@]}" | constraints_list_apply
    if declare -F constraints_list_footer >/dev/null 2>&1; then
      constraints_list_footer "tool(s)"
    fi
  fi

  if [[ "${missing_req}" -eq 1 ]]; then
    printf '\n'
    for t in "${required[@]+"${required[@]}"}"; do
      tools_resolve "${t}" >/dev/null 2>&1 && continue
      tools_print_howto "${t}"
    done
    return 1
  fi
  return 0
}

# Run the guide HOW_* command for a tool. Confirms unless --yes.
# Caller should only invoke for tools already known missing.
# Returns 0 on success; 0 with skip if somehow already present.
tools_install_one() {
  local tool="$1"
  local how

  # Belt-and-suspenders: never run pkg manager if tool is present
  if tools_resolve "${tool}" >/dev/null 2>&1; then
    log_skip "${tool} already installed — skipping"
    return 0
  fi

  if ! tools_guide_exists "${tool}"; then
    log_fatal "No install guide for '${tool}' (guides/tools/${tool}.guide)"
    return 1
  fi

  # shellcheck source=lib/tools/catalog.sh
  [[ -n "${LINUXBKUP_DEPS_CORE+x}" ]] || source "${LINUXBKUP_ROOT}/lib/tools/catalog.sh"
  how="$(tools_install_command "${tool}")"
  if [[ -z "${how}" ]]; then
    log_fatal "No install command for '${tool}' on this package family ($(tools_pkg_family))"
    tools_print_howto_body "${tool}"
    return 1
  fi

  tools_guide_pkg_how "${tool}"
  ui_section "Install ${tool}"
  if [[ "${DEPS_BANNER_SHOWN:-0}" -ne 1 ]]; then
    ui_kv "Detected" "$(tools_pkg_family)"
    ui_kv "Status" "missing"
    [[ -n "${TOOLS_GUIDE_PKG}" ]] && ui_kv "Package" "${TOOLS_GUIDE_PKG}"
  fi
  # Root hosts (iSH/Termux): guides often say `sudo …` — sudo may be absent.
  if [[ "${EUID:-$(id -u 2>/dev/null || echo 1000)}" -eq 0 ]]; then
    how="${how//sudo /}"
  fi
  ui_item note "Command: ${how}"

  if [[ "${LINUXBKUP_DRY_RUN:-0}" -eq 1 ]]; then
    log_info "dry-run — not executing install"
    return 0
  fi

  if [[ "${LINUXBKUP_DEPS_INTERACTIVE:-0}" -eq 1 ]]; then
    if ! safety_confirm "Run install for ${tool}?" "y"; then
      log_skip "install cancelled: ${tool}"
      return 1
    fi
  fi

  # Final check right before executing
  if tools_resolve "${tool}" >/dev/null 2>&1; then
    log_skip "${tool} appeared on PATH — skipping install"
    return 0
  fi

  if bash -lc "${how}"; then
    if tools_resolve "${tool}" >/dev/null 2>&1; then
      log_ok "${tool} installed → $(tools_resolve "${tool}")"
      return 0
    fi
    log_warn "${tool} install finished but command not on PATH yet — open a new shell?"
    return 1
  fi
  log_fatal "install command failed for ${tool}"
  return 1
}
