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
| `restore` | Reconstruct from archive (later) |
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
