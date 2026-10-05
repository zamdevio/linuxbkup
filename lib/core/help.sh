# shellcheck shell=bash
# Styled help / version output (matches terminal UI elsewhere).
# Convention: one flag per row; short alias listed when it exists.

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
  ui_kv "plan" "Show what backup would include/skip (no writes)"
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
  ui_kv "-a, --ask" "Interactive path decisions (wins over --yes)"
  ui_kv "-p, --profile" "easy|balanced|strict (default: balanced)"
  ui_kv "-n, --dry-run" "Plan only; make no modifications"
  ui_kv "-v, --verbose" "Human detail (sizes, progress notes)"
  ui_kv "-d, --debug" "Forensic detail on stderr (implies -v)"
  ui_kv "-q, --quiet" "Less non-essential output"
  ui_kv "-o, --output" "Archive path (default: ~/Backups/linuxbkup/… or Windows Downloads when mounted)"
  ui_kv "-u, --user" "Target /home/<name> (default: current user)"
  ui_kv "-k, --keep-stage" "Keep staging dir after successful backup"
  ui_kv "-S, --stage-dir" "Parent directory for staging"
  ui_kv "-m, --max-size" "Abort if staging exceeds SIZE (uncompressed; e.g. 2G, 500M)"
  ui_kv "-w, --workers" "Parallelism cap for checksums (default 4; auto 1–N by job size)"
  ui_kv "-r, --reclaim" "Interactively include regenerable skips"
  ui_kv "-R, --reclaim-all" "Include all regenerable skips (warn: large)"
  ui_kv "-j, --json" "Machine-readable output (plan --json)"
  ui_kv "-f, --force-overwrite" "Allow overwriting conflicting files on restore"
  ui_kv "--skip-reinstall" "Skip regenerable reinstalls (node_modules, …) on restore"
  ui_kv "--reinstall-only" "Only run regenerable reinstalls (skip home/config copy)"
  ui_kv "--mark-secret" "Treat path as secret (repeatable; age-encrypted)"
  ui_kv "--no-secrets" "Exclude secrets from backup"
  ui_kv "--secrets-plain" "Include secrets unencrypted (explicit)"
  ui_kv "--no-color" "Disable ANSI styling"
  ui_kv "--no-links" "Disable OSC 8 path/URL hyperlinks"
  printf '\n'

  ui_section "Path constraints"
  ui_item note "User flags win over built-ins in lib/constraints/"
  ui_kv "--no-defaults" "Ignore built-in path lists (use --include)"
  ui_kv "-i, --include" "Include path template or ERE (repeatable)"
  ui_kv "-e, --exclude" "Exclude matching paths — always wins"
  ui_kv "--no-gitignore" "Do not honor per-directory .gitignore during copy"
  ui_kv "--no-gitignores" "Alias of --no-gitignore"
  ui_item note "By default, every directory's .gitignore is applied (rsync dir-merge)"
  ui_item note "Built-in regenerables also strip node_modules, .next, caches, …"
  printf '\n'

  ui_section "Listing policy"
  ui_kv "-F, --full" "Show full lists (no top-N truncation)"
  ui_kv "-T, --top" "Show at most n items (default: 10)"
  printf '\n'

  ui_section "Examples"
  ui_item note "linuxbkup plan -F"
  ui_item note "linuxbkup plan -j"
  ui_item note "linuxbkup -y backup"
  ui_item note "linuxbkup -y -k -S /var/tmp backup"
  ui_item note "linuxbkup -i work -e scratch plan"
  ui_item note "linuxbkup verify ~/Backups/linuxbkup/host.tar.zst"
  ui_item note "sudo -E ./linuxbkup -k -f restore ~/Backups/linuxbkup/host.tar.zst"
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
      ui_kv "-u, --user" "Which /home/<name> to scan"
      ui_kv "-i, --include" "Extra include path / ERE (repeatable)"
      ui_kv "-e, --exclude" "Exclude matching paths (repeatable)"
      ui_kv "--no-defaults" "Ignore built-in path lists"
      ui_kv "-T, --top" "Show at most n list items"
      ui_kv "-F, --full" "Show full lists (no truncation)"
      ui_kv "--no-color" "Disable ANSI styling"
      ui_kv "--no-links" "Disable OSC 8 hyperlinks"
      ;;
    plan)
      ui_heading "linuxbkup plan"
      ui_item note "Show the home classification plan backup would use — no files written."
      printf '\n'
      ui_section "Usage"
      ui_item note "linuxbkup [globals] plan"
      ui_item note "linuxbkup plan -j"
      printf '\n'
      ui_section "Useful globals (same meaning as backup)"
      ui_kv "-F, --full" "Full include/skip tables"
      ui_kv "-T, --top" "Cap list length"
      ui_kv "-v, --verbose" "Filter-aware sizes"
      ui_kv "-y, --yes" "Show unexpected as auto-include"
      ui_kv "-a, --ask" "Interactive decisions (wins over --yes)"
      ui_kv "-p, --profile" "easy|balanced|strict"
      ui_kv "-u, --user" "Target home"
      ui_kv "-i, --include" "Extra include path / ERE"
      ui_kv "-e, --exclude" "Exclude matching paths"
      ui_kv "--no-defaults" "Ignore built-in rules"
      ui_kv "--no-secrets" "Secret paths excluded"
      ui_kv "--secrets-plain" "Secrets treated as plaintext"
      ui_kv "-j, --json" "Stable JSON envelope on stdout"
      ui_item note "Tips replay these flags into a ready-to-run backup command"
      ;;
    backup)
      ui_heading "linuxbkup backup"
      ui_item note "Stage metadata + classified home/config, pack tar.zst."
      printf '\n'
      ui_section "Usage"
      ui_item note "linuxbkup [globals] backup"
      printf '\n'
      ui_section "Requires"
      ui_item note "tar, zstd, rsync, du, sha256sum  (optional: age)"
      printf '\n'
      ui_section "Useful globals"
      ui_kv "-o, --output" "Archive destination (see platform defaults)"
      ui_kv "-n, --dry-run" "Plan without writing"
      ui_kv "-y, --yes" "Accept copy confirmation; soft-skip unreadable files"
      ui_kv "-a, --ask" "Interactive unexpected/large picks (ignores --yes)"
      ui_kv "-p, --profile" "easy|balanced|strict — large-path suggestions/defaults"
      ui_kv "-k, --keep-stage" "Keep staging dir after successful backup"
      ui_kv "-S, --stage-dir" "Parent directory for staging"
      ui_kv "-m, --max-size" "Abort if staging exceeds SIZE (uncompressed)"
      ui_kv "-w, --workers" "Checksum parallelism cap (default 4; scales down for tiny jobs)"
      ui_kv "-u, --user" "Home to back up"
      ui_kv "-i, --include" "Extra include path / ERE (repeatable)"
      ui_kv "-e, --exclude" "Exclude matching paths (repeatable)"
      ui_kv "-r, --reclaim" "Interactively include regenerable skips"
      ui_kv "-R, --reclaim-all" "Include all regenerable skips"
      ui_kv "--no-secrets" "Skip sensitive paths"
      ui_kv "--no-gitignore" "Do not apply per-directory .gitignore"
      ui_item note "Default: honor .gitignore in every directory during rsync"
      ui_item note "Also strips regenerables (node_modules, .next, caches, …)"
      ui_item note "Paths to copy listed large → small; progress shows live stage size"
      ui_item note "Full include/skip table: linuxbkup plan"
      ;;
    restore)
      ui_heading "linuxbkup restore"
      ui_item note "Extract → decrypt → rsync home/config → reinstall stripped node_modules."
      printf '\n'
      ui_section "Usage"
      ui_item note "linuxbkup [globals] restore <archive.tar.zst>"
      ui_item note "linuxbkup [globals] restore <staging-dir>"
      printf '\n'
      ui_section "What is restored"
      ui_item note "home/ + secrets/ → target user's \$HOME; config/etc → /etc (if writable)"
      ui_item note "Node projects from packages/reinstalls.json (npm/pnpm/yarn/bun)"
      ui_item note "Existing files: refused unless -f/--force-overwrite"
      ui_item note "sudo: home follows SUDO_USER (not /root); use -u root only for root's home"
      ui_item note "  sudo -E ./linuxbkup -k -f restore <archive>"
      printf '\n'
      ui_section "Reinstalls"
      ui_item note "-y / non-TTY: reinstall all recorded projects (failures skipped)"
      ui_item note "TTY pick: Enter=all · numbers/ranges · f=fzf · n=none · q=skip"
      ui_item note "--ask (-a): interactive project pick + overwrite confirms (wins over -y)"
      ui_item note "--reinstall-only: manifest + installs only (after PMs installed)"
      ui_item note "Before extract: peeks reinstalls.tsv; lists PMs with resolved Linux paths"
      ui_item note "Windows/interop shims (/mnt/…) are ignored — install Linux Node/PMs"
      ui_item note "Corepack/npm never prompt (CI=1) — non-interactive safe"
      ui_item note "PM output quiet unless -v; failures keep /tmp log + end report"
      ui_item note "Missing pnpm/yarn: tries corepack when Linux node is present"
      ui_item note "PM lists use top-10 policy — pass -F/--full or -T/--top <n>"
      ui_item note "PM per project comes from the source backup (lockfile / packageManager)"
      printf '\n'
      ui_section "Secrets"
      ui_item note "Passphrase: LINUXBKUP_SECRETS_PASS or LINUXBKUP_SECRETS_PASS_FILE (or TTY prompt)"
      printf '\n'
      ui_section "Requires"
      ui_item note "tar, zstd, rsync, sha256sum  (optional: age, openssl for secrets)"
      ui_item note "Linux-native pnpm/npm/yarn/bun for projects you choose to reinstall"
      printf '\n'
      ui_section "Useful globals"
      ui_kv "-u, --user" "Target home owner (default: you; under sudo: SUDO_USER)"
      ui_kv "-n, --dry-run" "Show plan only"
      ui_kv "-k, --keep-stage" "Keep extract directory after restore"
      ui_kv "-a, --ask" "Interactive overwrite + reinstall picks (wins over -y)"
      ui_kv "-f, --force-overwrite" "Replace existing home/secrets/config files"
      ui_kv "--skip-reinstall" "Do not run node (or later language) reinstalls"
      ui_kv "--reinstall-only" "Skip extract of home — only regenerate node_modules"
      ui_kv "-F/--full, -T/--top" "Listing policy for PM/tool lists (default top 10)"
      ui_kv "-y, --yes" "Safe defaults + reinstall all; pass must come from env"
      ;;
    verify)
      ui_heading "linuxbkup verify"
      ui_item note "Verify a finished archive or a staging directory left after a failed pack."
      printf '\n'
      ui_section "Usage"
      ui_item note "linuxbkup [globals] verify <archive.tar.zst>"
      ui_item note "linuxbkup [globals] verify <staging-dir>"
      printf '\n'
      ui_section "Examples"
      ui_item note "linuxbkup verify ~/Backups/linuxbkup/host-20260101.tar.zst"
      ui_item note "linuxbkup verify /tmp/linuxbkup.12345.67890"
      printf '\n'
      ui_section "Requires"
      ui_item note "Archive: tar, zstd, sha256sum"
      ui_item note "Staging: sha256sum (checksums.sha256 required)"
      ;;
    list)
      ui_heading "linuxbkup list"
      ui_item note "List backup contents at a high level."
      printf '\n'
      ui_section "Usage"
      ui_item note "linuxbkup [globals] list <backup>"
      ui_kv "-T, --top" "How many entries to show"
      ui_kv "-F, --full" "Show all entries"
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
