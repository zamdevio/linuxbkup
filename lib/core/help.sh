# shellcheck shell=bash
# Styled help / version output (matches terminal UI elsewhere).

linuxbkup_print_version() {
  ui_heading "linuxbkup"
  ui_kv "Version" "${LINUXBKUP_VERSION}"
  ui_kv_path "Root" "${LINUXBKUP_ROOT}"
  ui_item note "Bash-first Linux backup / restore"
  ui_item note "Works on desktop Linux, VPS, and WSL"
  printf '\n'
}

linuxbkup_usage() {
  ui_heading "linuxbkup"
  ui_item note "Safe, reconstructable Linux backup / restore"
  ui_item note "Works on desktop Linux, VPS, and WSL"
  printf '\n'

  ui_section "Usage"
  ui_item note "linuxbkup [global options] <command> [args]"
  printf '\n'

  ui_section "Commands"
  ui_kv "inspect" "Scan environment (distro, users, tools, sizes)"
  ui_kv "backup" "Create an intelligent backup archive"
  ui_kv "restore" "Reconstruct from a backup"
  ui_kv "verify" "Verify archive integrity / manifests"
  ui_kv "list" "List backup contents (high level)"
  ui_kv "deps" "Dependency status / install / howto"
  ui_kv "help" "Show this help (or: help <command>)"
  ui_kv "version" "Print version"
  printf '\n'

  ui_section "Global options"
  ui_kv "-y, --yes" "Accept safe defaults (not destructive overwrite)"
  ui_kv "--dry-run" "Plan only; make no modifications"
  ui_kv "-v, --verbose" "More detail"
  ui_kv "-q, --quiet" "Less non-essential output"
  ui_kv "--no-color" "Disable ANSI styling"
  ui_kv "--no-links" "Disable OSC 8 path/URL hyperlinks"
  ui_kv "-o, --output" "Archive path (default: ~/Backups/linuxbkup/… or Windows Downloads when mounted)"
  ui_kv "--user" "Target /home/<name> (default: current user)"
  ui_kv "--force-overwrite" "Allow overwriting conflicting files on restore"
  ui_kv "--no-secrets" "Exclude secrets from backup"
  ui_kv "--secrets-plain" "Include secrets unencrypted (explicit)"
  printf '\n'

  ui_section "Path constraints"
  ui_item note "User flags win over built-ins in lib/constraints/"
  ui_kv "--no-defaults" "Ignore built-in path lists (use --include)"
  ui_kv "--include" "Include path template or ERE (repeatable)"
  ui_kv "--exclude" "Exclude matching paths — always wins"
  printf '\n'

  ui_section "Listing policy"
  ui_kv "-F, --full" "Show full lists (no top-N truncation)"
  ui_kv "-T, --top" "Show at most n items (default: 10)"
  printf '\n'

  ui_section "Examples"
  ui_item note "linuxbkup inspect"
  ui_item note "linuxbkup -o ~/Backups/linuxbkup/host.tar.zst backup"
  ui_item note "linuxbkup verify ~/Backups/linuxbkup/host.tar.zst"
  printf '\n'

  ui_section "Also"
  ui_kv "-h, --help" "Show help"
  ui_kv "-V, --version" "Show version"
  printf '\n'

  ui_section "Principle"
  ui_item note "Back up what cannot be regenerated. Record recipes for what can."
  printf '\n'
}

# Per-command help. Args: command name
linuxbkup_cmd_help() {
  local cmd="$1"
  case "${cmd}" in
    inspect)
      ui_heading "linuxbkup inspect"
      ui_item note "Read-only environment scan — distro, users, tools, sizes, classification."
      printf '\n'
      ui_section "Usage"
      ui_item note "linuxbkup [globals] inspect"
      printf '\n'
      ui_section "Requires"
      ui_item note "du, find  (optional: timeout, numfmt, age, tar, zstd, rsync, …)"
      printf '\n'
      ui_section "Useful globals"
      ui_kv "--user" "Which /home/<name> to scan"
      ui_kv "--include/--exclude" "Filter constraint paths (regex)"
      ui_kv "--no-defaults" "Ignore built-in path lists"
      ui_kv "-T/--top, -F/--full" "List length policy"
      ui_kv "--no-color/--no-links" "Output styling"
      ;;
    backup)
      ui_heading "linuxbkup backup"
      ui_item note "Stage metadata + APT manuals + allowlisted home/config, pack tar.zst."
      printf '\n'
      ui_section "Usage"
      ui_item note "linuxbkup [globals] backup"
      printf '\n'
      ui_section "Requires"
      ui_item note "tar, zstd, rsync, du, sha256sum  (optional: age)"
      printf '\n'
      ui_section "Useful globals"
      ui_kv "-o, --output" "Archive destination (see platform defaults)"
      ui_kv "--dry-run" "Plan without writing"
      ui_kv "-y, --yes" "Accept copy confirmation"
      ui_kv "--user" "Home to back up"
      ui_kv "--no-secrets" "Skip sensitive paths"
      ui_kv "--include/--exclude" "Path constraints"
      ;;
    restore)
      ui_heading "linuxbkup restore"
      ui_item note "Reconstruct environment from a backup (later phase)."
      printf '\n'
      ui_section "Usage"
      ui_item note "linuxbkup [globals] restore <backup>"
      printf '\n'
      ui_section "Requires"
      ui_item note "tar, zstd, rsync, sha256sum  (optional: age)"
      printf '\n'
      ui_section "Useful globals"
      ui_kv "--dry-run" "Show plan only"
      ui_kv "--force-overwrite" "Replace conflicting files"
      ui_kv "-y, --yes" "Safe defaults (not overwrite)"
      ;;
    verify)
      ui_heading "linuxbkup verify"
      ui_item note "Verify archive integrity / manifests."
      printf '\n'
      ui_section "Usage"
      ui_item note "linuxbkup [globals] verify <backup>"
      ;;
    list)
      ui_heading "linuxbkup list"
      ui_item note "List backup contents at a high level."
      printf '\n'
      ui_section "Usage"
      ui_item note "linuxbkup [globals] list <backup>"
      ui_kv "-T/--top, -F/--full" "How many entries to show"
      ;;
    deps)
      ui_heading "linuxbkup deps"
      ui_item note "Dependency status, install, and How-To guides."
      printf '\n'
      ui_section "Usage"
      ui_item note "linuxbkup deps [status]"
      ui_item note "linuxbkup deps install [all|<tool>…]"
      ui_item note "linuxbkup deps howto <tool>"
      printf '\n'
      ui_section "Tips"
      ui_item note "Already-installed tools are skipped — never run apt for nothing."
      ui_item note "Guides: guides/tools/<name>.guide"
      ;;
    help|version)
      linuxbkup_usage
      ;;
    *)
      log_fatal "No help for unknown command: ${cmd}"
      return 2
      ;;
  esac
  printf '\n'
}

# Shared: if first args are -h/--help/help, print cmd help and return 0.
# Usage in commands: cmd_want_help "$@" && { linuxbkup_cmd_help inspect; return 0; }
cmd_want_help() {
  case "${1:-}" in
    -h|--help|help) return 0 ;;
    *) return 1 ;;
  esac
}
