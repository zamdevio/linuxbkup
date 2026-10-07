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
| `restore` | Extract → decrypt secrets → rsync home/config (needs `-f` to overwrite). `sudo` targets `SUDO_USER` home, not `/root`. Node reinstalls from manifest. |
| `verify` | Integrity check (archive or staging dir) |
| `list` | High-level archive listing |
| `deps` | Tool status / install / How-To / one-command bootstrap |

## Plan

```bash
linuxbkup plan
linuxbkup plan -F
linuxbkup plan --json
linuxbkup -y plan
linuxbkup -v plan
```

## Backup

```bash
linuxbkup -y backup
linuxbkup -o ~/Backups/linuxbkup/host.tar.zst backup
linuxbkup -k backup        # keep staging after success (path always printed)
```

Staging lives under `linuxbkup.<pid>.<rand>` (same family as restore extract). Archives are **atomic**: pack to `*.tar.zst.tmp` → integrity check → rename.

## Restore

```bash
linuxbkup -k -f restore ~/Backups/linuxbkup/host.tar.zst
sudo -E ./linuxbkup -k -f restore ~/Backups/linuxbkup/host.tar.zst
linuxbkup -k -f --skip-reinstall restore ~/Backups/linuxbkup/host.tar.zst
linuxbkup -y -f restore ~/Backups/linuxbkup/host.tar.zst
linuxbkup -y --reinstall-only restore ~/Backups/linuxbkup/host.tar.zst
```

Passphrase via `LINUXBKUP_SECRETS_PASS` / `_PASS_FILE` or TTY prompt. Existing files need `-f` (or `-a/--ask`).

Backup writes `packages/reinstalls.json` for workspace roots / lockfile dirs. Restore peeks `packages/reinstalls.tsv` and lists required PMs with resolved Linux paths. Reinstalls skip failed projects. TTY picker v2 + soft-quit batch (`q`) unchanged.

## Dependencies

```bash
linuxbkup deps
linuxbkup deps install          # missing core (one-command bootstrap when 2+ missing)
linuxbkup -y deps install all
linuxbkup deps howto fzf
```

Bootstrap detects **apk | apt | pacman | pkg (Termux) | dnf | yum | brew**.

## Supported hosts

| Host | Notes |
|------|-------|
| GNU Linux (desktop / VPS / WSL) | Happy path |
| Alpine / BusyBox | tar flag fallbacks; `deps` + `zstd` required; sha via shasum/openssl if needed |
| iSH / Termux | Best-effort — no FHS assumptions; run `deps` first |
| FAT / exFAT / NTFS / 9p mounts | rsync **metadata mode** — no hard-fail on chmod/symlink |

**Checksum providers:** `sha256sum` | `shasum -a 256` | `openssl dgst`.

**Tar:** impl probed (`gnu` / `busybox` / `bsd`); GNU-only flags omitted where unsupported.

## Stage paths

| Command | Path |
|---------|------|
| `backup` | `…/linuxbkup.<pid>.<rand>` |
| `backup -k` | same — **path printed** |
| `restore` (archive) | `…/linuxbkup-restore-<ts>.<pid>` — **path printed**; kept with `-k` |
| `verify` (archive) | `…/linuxbkup-verify-<ts>.<pid>` — **path printed** |

Parent: `-S/--stage-dir` if set, else `${TMPDIR:-/tmp}`.

## Path filters

```bash
linuxbkup inspect --exclude '\.cache' -T 5
linuxbkup -y backup --include /home/user/extra-pattern
```

Unexpected auto-includes with `-y` or non-TTY.

## Signals (TTY)

| Key | Behavior |
|-----|----------|
| **Ctrl+C** | `[INT]` notice → TERM→wait→KILL → menu on `/dev/tty`. Mid-reinstall: `q` = soft-quit batch. Wait: `LINUXBKUP_INT_STOP_WAIT_DS` (default 30 = 3s) |
| **Ctrl+Z** | Suspend whole job (`fg`/`bg`) on **backup and restore** (extract / rsync / reinstall). Children STOPped first, then process group |

## Logging

| Flag | Role |
|------|------|
| `-v` / `--verbose` | Human detail |
| `-d` / `--debug` | Forensic why/commands on stderr (implies `-v`) |

## Known remaining gaps

| Gap | Status |
|-----|--------|
| Full end-user docs site | Phases 06–07 |
| Real iSH/Termux/Kali soak | Checklist only — hardware run pending |
| Python / Go reinstall arrays | Queued (same JSON pattern) |
