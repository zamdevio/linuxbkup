# shellcheck shell=bash
# Shared constants, path helpers, global flag parsing.

WSLBKUP_VERSION="${WSLBKUP_VERSION:-0.1.0-dev}"

# Globals set by wslbkup_parse_globals
WSLBKUP_YES=0
WSLBKUP_DRY_RUN=0
WSLBKUP_VERBOSE=0
WSLBKUP_QUIET=0
WSLBKUP_OUTPUT=""
WSLBKUP_FORCE_OVERWRITE=0
WSLBKUP_NO_SECRETS=0
WSLBKUP_SECRETS_PLAIN=0
WSLBKUP_USER=""
WSLBKUP_POSITIONAL=()

wslbkup_usage() {
  cat <<'EOF'
wslbkup — safe, reconstructable WSL backup / restore

Usage:
  wslbkup [global options] <command> [args]

Commands:
  inspect              Scan environment (distro, users, capabilities, sizes)
  backup               Create an intelligent backup archive
  restore <backup>     Reconstruct from a backup
  verify <backup>      Verify archive integrity / manifests
  list <backup>        List backup contents (high level)
  help                 Show this help
  version              Print version

Global options:
  -y, --yes            Accept safe defaults (NOT destructive overwrite)
  --dry-run            Plan only; make no modifications
  -v, --verbose        More detail
  -q, --quiet          Less non-essential output
  -o, --output <path>  Backup output path (default: Windows Downloads/wslbkup/)
  --user <name>        Target /home/<name> (default: current user)
  --force-overwrite    Allow overwriting conflicting files on restore
  --no-secrets         Exclude secrets from backup
  --secrets-plain      Include secrets unencrypted (explicit; warned)
  -h, --help           Show help
  -V, --version        Show version

Principle:
  Back up what cannot be regenerated. Record recipes for what can.
EOF
}

wslbkup_parse_globals() {
  WSLBKUP_POSITIONAL=()
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
      -o|--output)
        [[ $# -ge 2 ]] || { echo "wslbkup: --output requires a path" >&2; exit 2; }
        WSLBKUP_OUTPUT="$2"
        shift 2
        ;;
      --user)
        [[ $# -ge 2 ]] || { echo "wslbkup: --user requires a name" >&2; exit 2; }
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
      -h|--help|-V|--version)
        # Leave for top-level command dispatch when they appear as "command"
        WSLBKUP_POSITIONAL+=("$1")
        shift
        ;;
      --)
        shift
        WSLBKUP_POSITIONAL+=("$@")
        break
        ;;
      -*)
        echo "wslbkup: unknown option: $1" >&2
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
