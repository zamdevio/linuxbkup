# shellcheck shell=bash
# Shared constants, path helpers, global flag parsing.

LINUXBKUP_VERSION="${LINUXBKUP_VERSION:-0.1.0-dev}"

# Globals set by linuxbkup_parse_globals
LINUXBKUP_YES=0
LINUXBKUP_ASK=0
LINUXBKUP_DRY_RUN=0
LINUXBKUP_VERBOSE=0
LINUXBKUP_DEBUG=0
LINUXBKUP_QUIET=0
LINUXBKUP_NO_COLOR=0
LINUXBKUP_NO_LINKS=0
LINUXBKUP_OUTPUT=""
LINUXBKUP_FORCE_OVERWRITE=0
LINUXBKUP_NO_SECRETS=0
LINUXBKUP_SECRETS_PLAIN=0
LINUXBKUP_USER=""
LINUXBKUP_NO_DEFAULTS=0
LINUXBKUP_LIST_FULL=0
LINUXBKUP_LIST_TOP=""
LINUXBKUP_JSON=0
LINUXBKUP_MAX_SIZE_BYTES=""
LINUXBKUP_PROFILE="balanced"
LINUXBKUP_KEEP_STAGE=0
LINUXBKUP_STAGE_DIR=""
LINUXBKUP_RECLAIM=0
LINUXBKUP_RECLAIM_ALL=0
LINUXBKUP_MARK_SECRET=()
LINUXBKUP_INCLUDE_REGEXES=()
LINUXBKUP_EXCLUDE_REGEXES=()
LINUXBKUP_POSITIONAL=()
# Soft-skip counter / skip-all for permission / partial copy issues
LINUXBKUP_PERM_SKIPS=0
LINUXBKUP_PERM_SKIP_ALL=0

# Help/version live in lib/core/help.sh (styled).

linuxbkup_parse_globals() {
  LINUXBKUP_POSITIONAL=()
  LINUXBKUP_INCLUDE_REGEXES=()
  LINUXBKUP_EXCLUDE_REGEXES=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -y|--yes)
        LINUXBKUP_YES=1
        shift
        ;;
      --ask)
        LINUXBKUP_ASK=1
        shift
        ;;
      --profile)
        [[ $# -ge 2 ]] || { log_fatal "--profile requires easy|balanced|strict"; exit 2; }
        LINUXBKUP_PROFILE="$2"
        shift 2
        ;;
      --keep-stage)
        LINUXBKUP_KEEP_STAGE=1
        shift
        ;;
      --stage-dir)
        [[ $# -ge 2 ]] || { log_fatal "--stage-dir requires a path"; exit 2; }
        LINUXBKUP_STAGE_DIR="$2"
        shift 2
        ;;
      --reclaim)
        LINUXBKUP_RECLAIM=1
        shift
        ;;
      --reclaim-all)
        LINUXBKUP_RECLAIM_ALL=1
        shift
        ;;
      --mark-secret)
        [[ $# -ge 2 ]] || { log_fatal "--mark-secret requires a path"; exit 2; }
        LINUXBKUP_MARK_SECRET+=("$2")
        shift 2
        ;;
      --dry-run)
        LINUXBKUP_DRY_RUN=1
        shift
        ;;
      -v|--verbose)
        LINUXBKUP_VERBOSE=1
        shift
        ;;
      -d|--debug)
        LINUXBKUP_DEBUG=1
        LINUXBKUP_VERBOSE=1
        shift
        ;;
      -q|--quiet)
        LINUXBKUP_QUIET=1
        shift
        ;;
      --no-color)
        LINUXBKUP_NO_COLOR=1
        shift
        ;;
      --no-links)
        LINUXBKUP_NO_LINKS=1
        shift
        ;;
      -o|--output)
        [[ $# -ge 2 ]] || { log_fatal "--output requires a path"; exit 2; }
        LINUXBKUP_OUTPUT="$2"
        shift 2
        ;;
      --user)
        [[ $# -ge 2 ]] || { log_fatal "--user requires a name"; exit 2; }
        LINUXBKUP_USER="$2"
        shift 2
        ;;
      --force-overwrite)
        LINUXBKUP_FORCE_OVERWRITE=1
        shift
        ;;
      --no-secrets)
        LINUXBKUP_NO_SECRETS=1
        shift
        ;;
      --secrets-plain)
        LINUXBKUP_SECRETS_PLAIN=1
        shift
        ;;
      --no-defaults)
        LINUXBKUP_NO_DEFAULTS=1
        shift
        ;;
      --include)
        [[ $# -ge 2 ]] || { log_fatal "--include requires a regex or path"; exit 2; }
        LINUXBKUP_INCLUDE_REGEXES+=("$2")
        shift 2
        ;;
      --exclude)
        [[ $# -ge 2 ]] || { log_fatal "--exclude requires a regex"; exit 2; }
        LINUXBKUP_EXCLUDE_REGEXES+=("$2")
        shift 2
        ;;
      -F|--full)
        LINUXBKUP_LIST_FULL=1
        shift
        ;;
      --json)
        LINUXBKUP_JSON=1
        shift
        ;;
      --max-size)
        [[ $# -ge 2 ]] || { log_fatal "--max-size requires a size (e.g. 2G, 500M)"; exit 2; }
        # shellcheck source=lib/fs/sizes.sh
        source "${LINUXBKUP_ROOT}/lib/fs/sizes.sh"
        if ! LINUXBKUP_MAX_SIZE_BYTES="$(fs_parse_size_to_bytes "$2")"; then
          log_fatal "invalid --max-size: $2 (use bytes or K/M/G/T)"
          exit 2
        fi
        if [[ "${LINUXBKUP_MAX_SIZE_BYTES}" -le 0 ]]; then
          log_fatal "--max-size must be > 0"
          exit 2
        fi
        shift 2
        ;;
      -T|--top)
        [[ $# -ge 2 ]] || { log_fatal "--top requires a number"; exit 2; }
        [[ "$2" =~ ^[0-9]+$ ]] || { log_fatal "--top must be an integer"; exit 2; }
        LINUXBKUP_LIST_TOP="$2"
        shift 2
        ;;
      -h|--help|-V|--version)
        LINUXBKUP_POSITIONAL+=("$1")
        shift
        ;;
      --)
        shift
        LINUXBKUP_POSITIONAL+=("$@")
        break
        ;;
      -*)
        log_fatal "unknown option: $1"
        exit 2
        ;;
      *)
        LINUXBKUP_POSITIONAL+=("$1")
        shift
        ;;
    esac
  done

  # shellcheck source=lib/core/profile.sh
  source "${LINUXBKUP_ROOT}/lib/core/profile.sh"
  linuxbkup_profile_validate || exit 2
  linuxbkup_apply_ask_yes_precedence
}

linuxbkup_require_cmd() {
  local c
  for c in "$@"; do
    command -v "${c}" >/dev/null 2>&1 || return 1
  done
  return 0
}

linuxbkup_phase_stub() {
  local phase="$1"
  local feature="$2"
  log_warn "${feature} is not implemented yet (phase ${phase})."
  log_info "See maintainer/phases/focus.md for current focus."
  return 0
}
