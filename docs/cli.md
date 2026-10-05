# CLI reference

```bash
linuxbkup --help
linuxbkup help plan
linuxbkup version
```

## Commands

| Command | Purpose |
|---------|---------|
| `inspect` | Read-only environment scan |
| `plan` | What backup would include/skip (no writes) |
| `backup` | Create archive |
| `restore` | Extract → decrypt secrets → rsync home/config (needs `-f` to overwrite). `sudo` targets `SUDO_USER` home, not `/root`. |
| `verify` | Integrity check (archive or staging dir) |
| `list` | High-level archive listing |
| `deps` | Tool status / install / How-To |

## Plan

```bash
linuxbkup plan
linuxbkup plan -F
linuxbkup plan --json
linuxbkup -y plan          # unexpected shown as auto-include
linuxbkup -v plan          # filter-aware sizes
```

## Backup

```bash
linuxbkup -y backup
linuxbkup -o ~/Backups/linuxbkup/host.tar.zst backup
```

Ends with a short summary and a tip to run `linuxbkup plan` for the full table. Unreadable files soft-skip (never auto-sudo).

## Restore

```bash
linuxbkup -k -f restore ~/Backups/linuxbkup/host.tar.zst
# /etc + same user home under sudo (not /root):
sudo -E ./linuxbkup -k -f restore ~/Backups/linuxbkup/host.tar.zst
# files only — skip node_modules regeneration:
linuxbkup -k -f --skip-reinstall restore ~/Backups/linuxbkup/host.tar.zst
# non-interactive: overwrite + reinstall all recorded Node projects:
linuxbkup -y -f restore ~/Backups/linuxbkup/host.tar.zst
# after installing pnpm/node — reinstall only (no home re-copy):
linuxbkup -y --reinstall-only restore ~/Backups/linuxbkup/host.tar.zst
```

Passphrase via `LINUXBKUP_SECRETS_PASS` / `_PASS_FILE` or TTY prompt. Existing files need `-f` (or `-a/--ask` to confirm per tree).  
Backup writes `packages/reinstalls.json` for **workspace roots / lockfile dirs** (not every nested `package.json`).  
Restore **peeks** `packages/reinstalls.tsv` and lists **required PMs with resolved Linux paths** (Windows/interop `/mnt/...` shims are ignored). Missing PMs get install recipes; Enter re-checks. PM/tool lists auto-truncate via listing policy (default **top 10**; `-F/--full`, `-T/--top <n>`).  
`-a/--ask` on restore: interactive reinstall project pick + overwrite confirms (wins over `-y`). TTY pick supports `a`/`n`/`1-3,5`/`f` (fzf)/`q`. After installing Linux PMs: `linuxbkup -y --reinstall-only restore <archive|staging>`. Tries `corepack` for pnpm/yarn when Linux `node` is present.

## Dependencies

```bash
linuxbkup deps
linuxbkup deps install          # missing core
linuxbkup deps install all      # core + optional, skip present
linuxbkup deps howto fzf
```

Install guides: `guides/tools/<name>.guide` (see maintainer systems doc for contributors).

## Path filters

```bash
linuxbkup inspect --exclude '\.cache' -T 5
linuxbkup -y backup --include /home/user/extra-pattern
```

Full `$HOME` shallow scan classifies known / secret / skip / unexpected. Unexpected auto-includes with `-y` or non-TTY.

## Signals (TTY)

| Key | Behavior |
|-----|----------|
| **Ctrl+C** | Pause → menu: retry / skip / continue / quit (keep staging) / quit+cleanup |
| **Ctrl+Z** | Suspend the whole job (`fg` / `bg` to resume) |

Works across the backup path (copy, checksums, pack, summary, …). Mid-pack Ctrl+C can retry `tar|zstd` without killing the run. `rsync` exit 20 is interrupt, not a soft-skip. Progress paints on stderr; cursor always restored on exit.

## Logging

| Flag | Role |
|------|------|
| `-v` / `--verbose` | Human detail (sizes, progress) |
| `-d` / `--debug` | Forensic why/commands on stderr (implies `-v`) |
