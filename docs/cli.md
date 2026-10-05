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
Reinstalls **skip failed projects** (never abort the whole run). Corepack/npm are forced non-interactive (`CI=1`, `COREPACK_ENABLE_DOWNLOAD_PROMPT=0`). PM logs are quiet unless `-v`; failures print the error line + `/tmp` log path. End summary lists OK / Skipped / Failed with reasons.  
`-a/--ask` on restore: interactive reinstall project pick + overwrite confirms (wins over `-y`).  
TTY **picker v2**: Enter=all · `e` exclude some · `i` include only · `p` PM filter · `g` grep path · `f` fzf · `n` none · `u` undo · `q` skip step. After fails: `[Enter]` re-run failed only · `[p]` pick again · `[q]` quit.  
**Signals during reinstall batch:** Ctrl+C → menu `r` retry / `s` skip / `c` continue / `q` quit batch (soft — partial summary, logs kept). Ctrl+Z suspends/resumes (`fg`/`bg`). After installing Linux PMs: `linuxbkup -y --reinstall-only restore <archive|staging>`.

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
| **Ctrl+C** | Pause → **menu on `/dev/tty`** (visible mid-PM): retry / skip / continue / quit. Mid-reinstall: `q` = **soft-quit** (partial summary). Empty Enter **re-prompts** (never silent quit) |
| **Ctrl+Z** | Suspend the whole job (`fg` / `bg` to resume) — backup **and** restore/reinstall |

Works across the backup path (copy, checksums, pack, summary, …). Mid-pack Ctrl+C can retry `tar|zstd` without killing the run. `rsync` exit 20 is interrupt, not a soft-skip. Progress paints on stderr; cursor always restored on exit.

## Logging

| Flag | Role |
|------|------|
| `-v` / `--verbose` | Human detail (sizes, progress) |
| `-d` / `--debug` | Forensic why/commands on stderr (implies `-v`) |
