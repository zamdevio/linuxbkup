# Phase 13 — platform compat + restore hardening

**Goal:** Same CLI on GNU desktop, VPS, WSL, Alpine/iSH, Termux — without assuming modern GNU binaries or a full FHS. Also finish restore UX gaps (Ctrl+Z, stage paths).

**Status:** open — **next Focus** after docs refresh. Source: Minis/iSH architectural audit (2026-10-08) + Kali soak.

**Non-goals:** Node/pnpm core rewrite; macOS as primary; dropping Bash-first.

## Why (audit + soak)

| Signal | Detail |
|--------|--------|
| Implementation coupling | Raw `tar` / `rsync` / `zstd` / `sha256sum` / `numfmt` calls; GNU flag assumptions (`tar --warning`, rsync extras) |
| Tool drift | BusyBox/iSH/old distros ≠ GNU coreutils; missing `zstd` by default; `shasum -a 256` vs `sha256sum` |
| Rootfs | Termux prefix, Alpine `apk`, WSL `/mnt/c` — hardcoded `/usr/bin` or FHS paths break |
| External mounts | FAT32/exFAT/APFS: `chmod`/symlinks fail under `rsync -a` |
| Interrupt UX | Restore Ctrl+Z can stick; backup unproven on some hosts |
| Stage paths | `verify` / `restore` ± `-k` do not always print stage path; naming differs from backup staging |
| Atomic archive | Partial `.tar.zst` / messy stage on crash — need tmp + rename after checksum |
| Bootstrap | Missing tools → install How-To only; no apk/apt/pacman auto path |
| Manifest version | Restore contract not fully versioned for v0.x → v1.0 |

## Doctrine

| Rule | Detail |
|------|--------|
| Host is untrusted | Probe binaries; never assume GNU. |
| Compat providers | No raw `tar`/`rsync`/`zstd` in `lib/cmd/` — wrappers map action → flags per impl (BusyBox/BSD/GNU). |
| Zero hardcoded paths | `$HOME`, `command -v`, platform helpers only. |
| Capability check | Startup probes: `tar_type=gnu|busybox|bsd`, `can_use_zstd`, checksum tool, rsync features. |
| TTY-agnostic | Every interactive path has `--yes` / non-TTY fallback. |
| Permission resilience | Restore to non-Linux mounts: metadata manifest mode; suggest sudo only when required. |
| Atomic commits | Write `*.tar.zst.tmp` → verify → `mv` to final name. |
| Manifest version | `schema.json` carries tool + schema version; older archives stay restorable. |
| Bash-first | Compat layer is shell. No Node in core CLI. |

## Slices

### A. Stage path contract (small, ship first)

- [ ] **A1** Shared stage/extract path helper — same naming as backup (`platform_staging_prefix` / `linuxbkup-<kind>-<ts>` under stage parent or `/tmp`)
- [ ] **A2** `backup -k`, `restore -k`, `verify` always **print** the kept stage/extract path (`ui_kv_path`)
- [ ] **A3** `restore` without `-k` still logs extract path for the duration of the run
- [ ] **A4** Smoke: stage path printed + consistent prefix

### B. Ctrl+Z parity (backup + restore)

- [ ] **B1** Reproduce restore hang on TTY (iSH + desktop) — which op wedges (`wait`, rsync, tar)
- [ ] **B2** Ensure `set -m` + `safety_on_tstp` + `CONT` cover restore extract/rsync/reinstall (not only backup pack)
- [ ] **B3** Backup Ctrl+Z on minimal shells (BusyBox job control quirks)
- [ ] **B4** Smoke: suspend/resume on a fake long op for backup **and** restore

### C. Compat layer (core of this phase)

- [ ] **C1** `lib/core/compat/` (or extend `lib/tools/compat.sh`): probe impl → `tar_type`, `zstd_ok`, `sha_tool`, `rsync_feat`
- [ ] **C2** `compat_tar_*` wrappers: pack/extract/list with GNU vs BusyBox flag sets (drop `--warning` where unsupported)
- [ ] **C3** `compat_sha256_*`: `sha256sum` | `shasum -a 256` | `openssl dgst`
- [ ] **C4** `compat_rsync_*`: feature probe; non-Linux dest → metadata-manifest mode (no hard-fail on chmod/symlink)
- [ ] **C5** `compat_numfmt` or pure-bash human sizes when numfmt missing/old
- [ ] **C6** Wire pack/extract/verify/checksum/restore_files through wrappers; smoke on BusyBox-like flag set
- [ ] **C7** Docs: `systems/platform.md` matrix + `docs/cli.md` “Supported hosts”

### D. Paths, bootstrap, atomic, manifests

- [ ] **D1** Audit `lib/` for hardcoded `/usr/bin`, `/home/user`, `/bin` — all via `command -v` / platform
- [ ] **D2** `deps` bootstrap: detect `apk|apt|pacman|pkg` and offer one-command install (still confirm on TTY; `-y` = documented non-interactive)
- [ ] **D3** Atomic archive: pack to `dest.tmp` → checksum verify → `mv`
- [ ] **D4** schema/tool version gates in verify + restore (soft-warn unknown, refuse only on hard incompat)
- [ ] **D5** iSH/Termux soak checklist under `maintainer/temp/` or docs — real commands + expected output

## Existing partial (do not redo)

- `lib/tools/compat.sh` — op probes (tar|zstd pipe, rsync -a, sha256sum) after presence checks
- `lib/env/capabilities.sh` — snapshot lines for rsync/tar/zstd/sha256sum
- `lib/fs/sizes.sh` — numfmt optional with fallback strings
- `lib/core/platform/` — detect, paths, windows mount, fs space
- Reinstall: workspace-root installs, nm auto-skip, interrupt notice + soft-quit (phases 11–12)

## Acceptance

- `linuxbkup` runs on a BusyBox-tar host for pack/extract/verify (flag fallbacks).
- Stage/extract path always printed and named like backup staging.
- Ctrl+Z: backup and restore suspend/resume without hang (desktop + iSH).
- Non-Linux output mount: backup does not die on rsync chmod/symlink — metadata mode + clear log.
- `deps` can install missing core via detected PM (with confirmation rules unchanged).
- Smoke green on GNU; focused compat cases for BusyBox flag sets.

## After ship

Fold into `shipped/` + `systems/{platform,tools,cli,backup-restore}.md`. Update README + `docs/cli.md`. Kali + iSH re-soak.

Umbrella: [`redesign.md`](./redesign.md). Focus: [`focus.md`](./focus.md). Prior shipped: reinstall 11–12.
