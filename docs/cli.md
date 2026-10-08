---
description: Command reference for inspect, plan, backup, restore, verify, deps, and global linuxbkup flags.
---

# CLI reference

```bash
linuxbkup --help
linuxbkup help <command>
linuxbkup version
```

Env prefix: **`LINUXBKUP_*` only**. Examples use generic paths (`/home/user`, `~/Backups/linuxbkup/…`).

## Commands

| Command | Purpose |
|---------|---------|
| `inspect` | Read-only environment scan + default destination |
| `plan` | What backup would include/skip (no writes); `--json` |
| `backup` | Scan → stage → checksum → atomic `tar.zst` |
| `restore` | Extract → secrets → home/config rsync → Node reinstalls |
| `verify` | Integrity check (archive **or** staging dir) |
| `list` | High-level archive listing (thin) |
| `deps` | Tool status / install / How-To / one-command bootstrap |
| `help` / `version` | Help and version |

## Global flags

| Flag | Role |
|------|------|
| `-y, --yes` | Safe defaults (not destructive overwrite) |
| `-a, --ask` | Interactive decisions (wins over `--yes`) |
| `-p, --profile` | `easy` \| `balanced` \| `strict` |
| `-n, --dry-run` | Plan only |
| `-v` / `-d` / `-q` | Verbose / debug (implies `-v`) / quiet |
| `-o, --output` | Archive path |
| `-u, --user` | Target home owner |
| `-k, --keep-stage` | Keep stage/extract dir (path printed) |
| `-S, --stage-dir` | Parent directory for staging |
| `-m, --max-size` | Abort if staging exceeds SIZE (e.g. `2G`) |
| `-w, --workers` | Parallelism cap (default 4) |
| `-r` / `-R` | Reclaim regenerables interactively / all |
| `-i` / `-e` | Include / exclude ERE (repeatable) |
| `-j, --json` | Machine-readable (`plan --json`) |
| `-f, --force-overwrite` | Allow restore overwrites |
| `-F` / `-T` | List full / top-N |
| `--skip-reinstall` | Skip Node reinstalls on restore |
| `--reinstall-only` | Manifest + installs only |
| `--mark-secret` | Treat path as secret (repeatable) |
| `--no-secrets` / `--secrets-plain` | Exclude secrets / include unencrypted |
| `--no-defaults` | Ignore built-in path rules |
| `--no-gitignore` | Do not honor per-directory `.gitignore` |
| `--no-color` / `--no-links` | Disable ANSI / OSC 8 |

## inspect

```bash
linuxbkup inspect
linuxbkup inspect -F
linuxbkup -v inspect
```

## plan

```bash
linuxbkup plan
linuxbkup plan -F
linuxbkup plan --json
linuxbkup -y plan
linuxbkup -v plan          # per-path sizes (slower)
```

Unexpected paths: auto-include under `-y` / non-TTY; interactive under `--ask`.

## backup

```bash
linuxbkup -y backup
linuxbkup -o ~/Backups/linuxbkup/host.tar.zst backup
linuxbkup -k backup
linuxbkup -y -p strict -m 2G -w 8 backup
```

- Stage path always printed; kept with `-k`
- Atomic pack: `*.tar.zst.tmp` → verify → final name
- Secrets: see [secrets.md](./secrets.md)

## restore

```bash
linuxbkup -k -f restore ~/Backups/linuxbkup/host.tar.zst
sudo -E ./linuxbkup -k -f restore ~/Backups/linuxbkup/host.tar.zst
linuxbkup -k -f --skip-reinstall restore ~/Backups/linuxbkup/host.tar.zst
linuxbkup -y -f restore ~/Backups/linuxbkup/host.tar.zst
linuxbkup -y --reinstall-only restore ~/Backups/linuxbkup/host.tar.zst
```

- Overwrite requires `-f` (or `-a` in a TTY) — never implied by `-y`
- Extract path printed; kept with `-k`
- Node reinstalls from `packages/reinstalls.json`; failures skip, never abort the run
- TTY picker: `e` exclude · `i` include-only · `p` PM · `g` grep · `f` fzf · `n` none · `u` undo · Enter=all

## verify

```bash
linuxbkup verify ~/Backups/linuxbkup/host.tar.zst
linuxbkup verify /tmp/linuxbkup.<pid>.<rand>
```

Payload checksum mismatches **fail**. Missing `schema.json` / events drift → soft warnings.

## deps

```bash
linuxbkup deps
linuxbkup deps status
linuxbkup deps install
linuxbkup -y deps install all
linuxbkup deps howto zstd
```

Bootstrap families: **apk · apt · pacman · pkg (Termux) · dnf · yum · brew**.

## Stage / extract paths

| Command | Path |
|---------|------|
| `backup` | `…/linuxbkup.<pid>.<rand>` |
| `backup -k` | printed on success |
| `restore` (archive) | `…/linuxbkup-restore-<ts>.<pid>` — printed; kept with `-k` |
| `verify` (archive) | `…/linuxbkup-verify-<ts>.<pid>` — printed |

Parent: `-S` or `${TMPDIR:-/tmp}`.

## Signals (TTY)

| Key | Behavior |
|-----|----------|
| **Ctrl+C** | `[INT]` notice → children stop → menu (`r`/`s`/`c`/`q`/`x`). Mid-reinstall `q` = soft-quit batch |
| **Ctrl+Z** | Suspend whole job on backup **and** restore (`fg`/`bg`) |

Wait after Ctrl+C: `LINUXBKUP_INT_STOP_WAIT_DS` (default 30 = 3s).

## Hosts (summary)

GNU Linux happy path; Alpine/BusyBox/iSH/Termux best-effort via compat + `deps`. External FAT/exFAT/NTFS/9p: rsync metadata mode. Full matrix: [platforms.md](./platforms.md).
