# shellcheck shell=bash
# Shared constants, path helpers, global flag parsing.

WSLBKUP_VERSION="${WSLBKUP_VERSION:-0.1.0-dev}"

# Globals set by wslbkup_parse_globals
WSLBKUP_YES=0
WSLBKUP_DRY_RUN=0
WSLBKUP_VERBOSE=0
WSLBKUP_QUIET=0
WSLBKUP_NO_COLOR=0
WSLBKUP_NO_LINKS=0
WSLBKUP_OUTPUT=""
WSLBKUP_FORCE_OVERWRITE=0
WSLBKUP_NO_SECRETS=0
WSLBKUP_SECRETS_PLAIN=0
WSLBKUP_USER=""
WSLBKUP_NO_DEFAULTS=0
WSLBKUP_LIST_FULL=0
WSLBKUP_LIST_TOP=""
WSLBKUP_INCLUDE_REGEXES=()
WSLBKUP_EXCLUDE_REGEXES=()
WSLBKUP_POSITIONAL=()

# Help/version live in lib/core/help.sh (styled).

wslbkup_parse_globals() {
  WSLBKUP_POSITIONAL=()
  WSLBKUP_INCLUDE_REGEXES=()
  WSLBKUP_EXCLUDE_REGEXES=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -y|--yes)
        WSLBKUP_YES=1
        shift
        ;;
      --dry-run)
        WSLBKUP_DRY_RUN=1
        shift
        ;;
      -v|--verbose)
        WSLBKUP_VERBOSE=1
        shift
        ;;
      -q|--quiet)
        WSLBKUP_QUIET=1
        shift
        ;;
      --no-color)
        WSLBKUP_NO_COLOR=1
        shift
        ;;
      --no-links)
        WSLBKUP_NO_LINKS=1
        shift
        ;;
      -o|--output)
        [[ $# -ge 2 ]] || { log_fatal "--output requires a path"; exit 2; }
        WSLBKUP_OUTPUT="$2"
        shift 2
        ;;
      --user)
        [[ $# -ge 2 ]] || { log_fatal "--user requires a name"; exit 2; }
        WSLBKUP_USER="$2"
        shift 2
        ;;
      --force-overwrite)
        WSLBKUP_FORCE_OVERWRITE=1
        shift
        ;;
      --no-secrets)
        WSLBKUP_NO_SECRETS=1
        shift
        ;;
      --secrets-plain)
        WSLBKUP_SECRETS_PLAIN=1
        shift
        ;;
      --no-defaults)
        WSLBKUP_NO_DEFAULTS=1
        shift
        ;;
      --include)
        [[ $# -ge 2 ]] || { log_fatal "--include requires a regex or path"; exit 2; }
        WSLBKUP_INCLUDE_REGEXES+=("$2")
        shift 2
        ;;
      --exclude)
        [[ $# -ge 2 ]] || { log_fatal "--exclude requires a regex"; exit 2; }
        WSLBKUP_EXCLUDE_REGEXES+=("$2")
        shift 2
        ;;
      -F|--full)
        WSLBKUP_LIST_FULL=1
        shift
        ;;
      -T|--top)
        [[ $# -ge 2 ]] || { log_fatal "--top requires a number"; exit 2; }
        [[ "$2" =~ ^[0-9]+$ ]] || { log_fatal "--top must be an integer"; exit 2; }
        WSLBKUP_LIST_TOP="$2"
        shift 2
        ;;
      -h|--help|-V|--version)
        WSLBKUP_POSITIONAL+=("$1")
        shift
        ;;
      --)
        shift
        WSLBKUP_POSITIONAL+=("$@")
        break
        ;;
      -*)
        log_fatal "unknown option: $1"
        exit 2
        ;;
      *)
        WSLBKUP_POSITIONAL+=("$1")
        shift
        ;;
    esac
  done
}

wslbkup_require_cmd() {
  local c
  for c in "$@"; do
    command -v "${c}" >/dev/null 2>&1 || return 1
  done
  return 0
}

wslbkup_phase_stub() {
  local phase="$1"
  local feature="$2"
  log_warn "${feature} is not implemented yet (phase ${phase})."
  log_info "See maintainer/phases/focus.md for current focus."
  return 0
}
