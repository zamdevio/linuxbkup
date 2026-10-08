# Concepts

What linuxbkup backs up, what it refuses to treat as precious, and how safety and portability actually work.

## The product in one line

**Back up what cannot be reliably regenerated. Record what can.**

That means:

- **Included (by default intent):** home config, dotfiles, selected project data, secrets you mark, package manifests (`packages/`, APT manuals, Node reinstall manifests).
- **Skipped as regenerable:** `node_modules`, virtualenvs, language/PM caches, build outputs, mise/asdf/nvm install trees, and similar — stripped by filter rules unless you force them back with `--reclaim` / `--reclaim-all`.
- **Not a goal:** whole-disk images, `/usr`, or replacing a real disk-level backup for disaster recovery of the OS itself.

## Pipeline

```text
plan/inspect   read-only view of what would be included
backup         classify → stage → seal → pack (atomic tar.zst)
verify         extract (or use a stage dir) → checksums + schema soft-check
restore        extract → decrypt secrets → rsync home/config → reinstalls
```

Each step prints what it is doing. Long steps can be interrupted with a menu (Ctrl+C) or suspended (Ctrl+Z).

## Classification

1. Scan `$HOME` shallowly (plus known backup roots from built-in rules).
2. Classify paths: known include, regenerable skip, secret, unexpected.
3. Report **unexpected** paths. With `-y` or non-TTY they auto-include; with `--ask` / interactive TTY you decide.
4. Per-directory `.gitignore` is honored on copy unless `--no-gitignore`.

User flags win over built-ins: `--include` / `--exclude` (ERE), `--no-defaults`.

## Safety model

| Rule | Behavior |
|------|----------|
| Overwrite on restore | Requires `-f/--force-overwrite`. `--yes` alone is **never** enough |
| Secrets under `--yes` | Passphrase from `LINUXBKUP_SECRETS_PASS` / `_PASS_FILE`, or explicit `--no-secrets` / `--secrets-plain` |
| Partial archives | Pack writes `*.tar.zst.tmp` → integrity check → rename. Crash does not leave a half-written final archive |
| Sudo restore | Targets `SUDO_USER` home, not `/root`, unless you pass `-u root` explicitly |
| Permission denials on copy | Soft-skip with a warning — never auto-sudo |
| Interrupt | Ctrl+C menu: retry / skip / continue / quit. Mid-reinstall `q` soft-quits the batch only |

## Portability

The CLI does **not** assume modern GNU coreutils on every host:

- **tar** impl is probed (GNU / BusyBox / BSD); GNU-only flags are omitted where unsupported
- **Checksums** work with `sha256sum`, `shasum -a 256`, or `openssl dgst`
- **rsync** on FAT/exFAT/NTFS/9p-style mounts switches to metadata mode (no hard-fail on chmod/symlink)
- **Paths** resolve via `command -v` / platform helpers — no hardcoded `/usr/bin/...` in product code
- **Package managers:** `deps` detects apk, apt, pacman, Termux `pkg`, dnf, yum, brew

Happy path remains GNU Linux (desktop, VPS, WSL). See [Platforms](./platforms.md).

## What this is not

- Not a disk imaging tool
- Not a secrets vault or password manager
- Not a security audit — treat restore targets you do not control carefully
- Not a replacement for offsite replication — copy the archive yourself after backup

## Naming

- Binary / product: **`linuxbkup`**
- Env prefix: **`LINUXBKUP_*` only**
- Default archive dir: **`~/Backups/linuxbkup/`** (or Windows Downloads when a WSL mount resolves)

Next: [Guide](./guide.md) · [Schema](./schema.md)
