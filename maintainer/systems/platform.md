# System — platform

`lib/core/platform/` — host detection and portable defaults. Commands call `platform_*` helpers; no `/mnt/c` hardcoding in `lib/cmd/`.

| File | Role |
|------|------|
| `detect.sh` | `platform_kind` → `linux` \| `wsl` \| `unknown`; `platform_has_windows_mount` |
| `paths.sh` | Default archive dir/name, staging prefix, inspect dest preview |
| `windows.sh` | Optional Windows profile → Downloads path when mount exists |
| `fs_space.sh` | Available bytes/human helpers (space preflight later) |

## Destination policy

1. `-o` / `--output` always wins (`LINUXBKUP_OUTPUT`).
2. Else if Windows Downloads resolves → `…/Downloads/linuxbkup/<distro>-<ts>.tar.zst`.
3. Else native → `$HOME/Backups/linuxbkup/<distro>-<ts>.tar.zst`.

## Callers

- `lib/cmd/inspect.sh` — `platform_print_backup_destination`
- `lib/cmd/backup.sh` — `platform_default_archive_path`
- `lib/backup/stage.sh` — `platform_staging_prefix` when loaded
