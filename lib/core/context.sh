# shellcheck shell=bash
# Per-command context banner: what we're doing + tool prerequisites.

# shellcheck source=lib/tools/check.sh
source "${LINUXBKUP_ROOT}/lib/tools/check.sh"

# cmd_context_begin <command> --required ... --optional ... [--desc "..."]
# Exits 2 if required tools are missing.
cmd_context_begin() {
  local command="$1"
  shift
  local -a required=() optional=()
  local desc="" mode=""
  local user home

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --required) mode="required"; shift ;;
      --optional) mode="optional"; shift ;;
      --desc)
        desc="$2"
        shift 2
        ;;
      *)
        if [[ "${mode}" == "optional" ]]; then
          optional+=("$1")
        elif [[ "${mode}" == "required" ]]; then
          required+=("$1")
        else
          log_fatal "cmd_context_begin: pass --required/--optional before tool names"
          exit 2
        fi
        shift
        ;;
    esac
  done

  if [[ -n "${LINUXBKUP_USER:-}" ]]; then
    user="${LINUXBKUP_USER}"
  else
    user="${USER:-$(id -un)}"
  fi
  home="$(getent passwd "${user}" 2>/dev/null | cut -d: -f6 || true)"
  [[ -n "${home}" ]] || home="/home/${user}"

  ui_heading "linuxbkup ${command}"
  [[ -n "${desc}" ]] && ui_item note "${desc}"
  ui_kv "Version" "${LINUXBKUP_VERSION}"
  ui_kv "User" "${user}"
  ui_kv_path "Home" "${home}"
  [[ "${LINUXBKUP_DRY_RUN:-0}" -eq 1 ]] && ui_kv "Mode" "dry-run"
  [[ "${LINUXBKUP_YES:-0}" -eq 1 ]] && ui_kv "Yes" "enabled (safe defaults only)"
  [[ "${LINUXBKUP_NO_DEFAULTS:-0}" -eq 1 ]] && ui_kv "Defaults" "off (--no-defaults)"
  if [[ "${LINUXBKUP_LIST_FULL:-0}" -eq 1 ]]; then
    ui_kv "List" "full"
  elif [[ -n "${LINUXBKUP_LIST_TOP:-}" ]]; then
    ui_kv "List" "top ${LINUXBKUP_LIST_TOP}"
  else
    ui_kv "List" "top ${CONSTRAINTS_LIST_DEFAULT_TOP:-10} (default)"
  fi
  if [[ "${#LINUXBKUP_INCLUDE_REGEXES[@]}" -gt 0 ]]; then
    ui_kv "Include" "${LINUXBKUP_INCLUDE_REGEXES[*]}"
  fi
  if [[ "${#LINUXBKUP_EXCLUDE_REGEXES[@]}" -gt 0 ]]; then
    ui_kv "Exclude" "${LINUXBKUP_EXCLUDE_REGEXES[*]}"
  fi

  printf '\n'
  ui_section "Tools"
  if ! tools_check --required "${required[@]+"${required[@]}"}" --optional "${optional[@]+"${optional[@]}"}"; then
    log_fatal "Missing required tools for '${command}'. Install them, then re-run."
    exit 2
  fi
  printf '\n'
}
