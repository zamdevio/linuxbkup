# System — platform

`lib/core/platform/` — host detection and portable defaults. Commands call `platform_*` helpers; no `/mnt/c` hardcoding in `lib/cmd/`.

| File | Role |
|------|------|
| `detect.sh` | `platform_kind` → `linux` \| `wsl` \| `unknown`; `platform_has_windows_mount`; `platform_linux_command` (Linux-native PM resolve) |
| `paths.sh` | Default archive dir/name, staging prefix, inspect dest preview |
| `windows.sh` | Optional Windows profile → Downloads path when mount exists |
| `fs_space.sh` | Available bytes/human helpers (space preflight) |

## Destination policy

1. `-o` / `--output` always wins (`LINUXBKUP_OUTPUT`).
2. Else if Windows Downloads resolves → `…/Downloads/linuxbkup/<distro>-<ts>.tar.zst`.
3. Else native → `$HOME/Backups/linuxbkup/<distro>-<ts>.tar.zst`.

## Callers

- `lib/cmd/inspect.sh` — `platform_print_backup_destination`
- `lib/cmd/backup.sh` — `platform_default_archive_path`
- `lib/backup/stage.sh` — `platform_staging_prefix` when loaded

## Portability (phase 13 — open)

Assumes **GNU-flavored** tools today. Open work in [`../phases/13-platform-compat.md`](../phases/13-platform-compat.md):

- Probe `tar` impl (GNU vs BusyBox vs BSD); wrap pack/extract flags
- Checksum tool fallbacks (`sha256sum` / `shasum -a 256` / openssl)
- rsync feature probe + metadata mode on FAT/exFAT/APFS destinations
- Zero hardcoded `/usr/bin` / `/home/...` — `$HOME` + `command -v`
- Stage path naming shared across backup/restore/verify
- Termux prefix / Alpine `apk` / iSH minimal rootfs

Until then: treat non-GNU hosts as **best-effort**; `linuxbkup deps` + compat probes (`lib/tools/compat.sh`) are the gate, not a full abstraction layer.
