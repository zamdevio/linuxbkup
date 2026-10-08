# System — platform

`lib/core/platform/` — host detection and portable defaults. Commands call `platform_*` helpers; no `/mnt/c` hardcoding in `lib/cmd/`.

| File | Role |
|------|------|
| `detect.sh` | `platform_kind` → `linux` \| `wsl` \| `unknown`; `platform_has_windows_mount`; `platform_linux_command` (Linux-native PM resolve) |
| `paths.sh` | Default archive dir/name; fallback `compat_stage_path` when compat not loaded |
| `windows.sh` | Optional Windows profile → Downloads path when mount exists |
| `fs_space.sh` | Available bytes/human helpers (space preflight) |

## Destination policy

1. `-o` / `--output` always wins (`LINUXBKUP_OUTPUT`).
2. Else if Windows Downloads resolves → `…/Downloads/linuxbkup/<distro>-<ts>.tar.zst`.
3. Else native → `$HOME/Backups/linuxbkup/<distro>-<ts>.tar.zst`.

## Stage path contract (shipped — phase 13 A)

One helper owns stage/extract naming: **`lib/core/compat/compat.sh` → `compat_stage_path <kind>`**.

| Kind | Basename | Parent |
|------|----------|--------|
| `backup` | `linuxbkup.<pid>.<rand>` | `-S/--stage-dir` or `${TMPDIR:-/tmp}` |
| `restore` | `linuxbkup-restore-<ts>.<pid>` | same |
| `verify` | `linuxbkup-verify-<ts>.<pid>` | same |

Print contract: `backup -k` / `restore -k` / `verify` always `ui_kv_path` the stage/extract path (`compat_print_stage_path`). Restore without `-k` still logs the extract path for the run duration; EXIT removes it unless kept.

## Compat layer (shipped — phase 13 C)

`lib/core/compat/compat.sh` — probe host tools once, map actions → portable flags.

| Probe | Values |
|-------|--------|
| `compat_tar_type` | `gnu` \| `busybox` \| `bsd` \| `unknown` |
| `compat_sha_tool` | `sha256sum` \| `shasum -a 256` \| `openssl dgst` |
| `compat_rsync_feat` | `filter exclude` [+ `chown`] [+ `progress`] |
| `compat_find_type` | `gnu` \| `busybox` \| `bsd` \| `unknown` (BusyBox has no `-printf`) |
| `compat_zstd_ok` | compress/test probe |

Wrappers: `compat_tar_{pack,extract,list,member}_stream` (drop GNU `--warning` when unsupported), `compat_zstd_{compress,decompress}`, `compat_sha256_{hash,check_file}`, `compat_rsync_args_for` / `compat_rsync_needs_meta` (FAT/exFAT/NTFS/9p → metadata mode: `-rlt --no-perms --no-group --no-owner`, no chmod/symlink hard-fail), `compat_numfmt_human` (numfmt or pure-bash IEC), `compat_schema_gate` (soft-warn unknown schema/tool version), `compat_find_rel_files` (relative path list; GNU `-printf` or `cd`+`sed` strip).

Context banner prints Tar/Checksum/Rsync capability matrix after probes.

## Callers

- `lib/cmd/inspect.sh` — `platform_print_backup_destination`
- `lib/cmd/backup.sh` — `platform_default_archive_path` + stage path print
- `lib/backup/stage.sh` — `compat_stage_path backup`
- `lib/cmd/restore.sh` / `lib/cmd/verify.sh` — extract via compat wrappers + shared naming

## Zero hardcoded paths (phase 13 D1)

`lib/` audit: no `/usr/bin/{tar,rsync,zstd,sha256sum,openssl}` literals. Tools resolve via `command -v` / `platform_linux_command` / compat probes. PM family detection uses `command -v` (Termux `pkg`, Alpine `apk`, apt/dnf/yum/pacman/brew).

## Supported hosts (phase 13)

| Host | Status |
|------|--------|
| GNU Linux (desktop/VPS/WSL) | Happy path |
| Alpine / BusyBox tar | Pack/extract/verify via flag fallbacks; `deps` + zstd required |
| iSH / Termux | Best-effort after soak; `pkg`/`apk` bootstrap; no FHS assumptions; no `sudo` when already root; no `find -printf`; no process substitution in detect/classify hot paths |
| External FAT/exFAT/NTFS/9p mounts | rsync metadata mode — no hard-fail on chmod/symlink |

Until soak lands on real iSH/Termux hardware: treat those as best-effort. Gate remains `linuxbkup deps` + compat probes.
