# System — backup / restore

## Live today

| Piece | Path / behavior |
|-------|-----------------|
| Backup cmd | `lib/cmd/backup.sh` |
| Staging / home copy | `lib/backup/` |
| Pack + checksums | `lib/archive/` (atomic: `dest.tmp` → verify → `mv`) |
| Verify helpers | `lib/archive/verify.sh` (compat sha256 check + schema gate) |
| APT manuals | `modules/apt.sh` (and backup orchestration) |
| Default dest | `lib/core/platform/paths.sh` — native `~/Backups/linuxbkup/` or Windows Downloads when mounted |
| Verify | `lib/cmd/verify.sh` — **archive** (`*.tar.zst`) **or staging directory** with `checksums.sha256` |
| Profiles / ask | `lib/core/profile.sh` + `lib/ask/select.sh` |
| Failure UX | Staging kept if pack fails; INDEX write ignores `find\|head` SIGPIPE |
| Compat layer | `lib/core/compat/compat.sh` — tar/sha/rsync/numfmt wrappers + stage paths |

Home/config from **full-home classification**. Decisions: `--ask` interactive (unexpected + large); `--yes` uses profile large defaults; non-TTY ≈ `--yes`. Regenerables skipped (rsync filter stack + expanded language/framework/PM globs + `*.pyc` etc.). Per-directory `.gitignore` honored unless `--no-gitignore`.

**Fail-fast (phase 09):** secrets mode + disk floor checked in Preflight **before** snapshot/copy; passphrase required under `--yes` before any heavy work. Preflight banner shows profile / gitignore / max-size / secrets at a glance (`backup_preflight_banner`). Backup prints `ui_step` labels: preflight → detect → capture → stage → seal → pack → summary. Estimates use byte-accurate filtered `du`. Space gate (`lib/backup/preflight.sh`) re-checks with estimate+10% before rsync confirm.

Backup prints shared **environment snapshot** (`lib/env/snapshot.sh`) after preflight. `-k/--keep-stage` / `-S/--stage-dir` control staging lifecycle. **Stage path always printed** (`compat_print_stage_path`).

Long steps (`classify`, `copy`, `secrets`, `index`, `checksum`, `pack`, `summary`, …) use `linuxbkup_op_begin` + `linuxbkup_interrupt_resolve` (see [`cli.md`](./cli.md)). Copy/pack long waits run under `linuxbkup_without_monitor` so tty Ctrl+C cannot skip the menu via a child-only process group.

**Layout:** large modules split into `lib/**/<name>/*.sh` with thin barrels at the old path — budget + slices in [`../phases/refactor.md`](../phases/refactor.md) (soft ≤250 / hard 400; parallel). Smoke suite: `tests/smoke.sh` runner + `tests/smoke/NN-*.sh` (R-SMOKE).

**events.jsonl:** written under `metadata/` through pack ok; detached before stage cleanup (summary is verbose-only). Excluded from `checksums.sha256` — verify soft-warns if an older archive hashed it and it drifts. Payload mismatches still **fail + stop**.

## Atomic archives (shipped — phase 13 D)

`archive_pack_tar_zst` writes `${dest}.tmp.$$` → `zstd -t` + `tar -tf` integrity → `mv -f` to final name. Interrupt/failure removes the tmp file; the final archive is never a partial `.tar.zst`.

## Restore (live)

`lib/cmd/restore.sh` + `lib/backup/restore_files.sh` + `lib/backup/secrets_crypt.sh`:

1. Extract archive (or use staging) → schema soft-check (compat gate)
2. Decrypt `secrets.tar.age` when present
3. Rsync `home/` + `secrets/` → target user home; `config/etc` → `/etc` if writable
4. Overwrite gate: existing files require `-f/--force-overwrite` (`--yes` alone is never enough)
5. **sudo:** `env_resolve_user` prefers `SUDO_USER` (not root) unless `-u` is set; home/secrets get `rsync --chown=user:group`; `/etc` still applies as root. Refuses dumping into `/root` when `SUDO_USER` is a normal user.
6. **Non-Linux dest:** `compat_rsync_args_for` switches to metadata mode (no chmod/symlink hard-fail) with a clear log line.

**Node reinstalls:** after home copy, `modules/node.sh` writes `packages/reinstalls.json` (+ `.tsv`) for **workspace roots / lockfile dirs** (skips nested packages, `.claude`, `.var`, fixtures). Before full extract, restore **peeks** `packages/reinstalls.tsv` (compat tar member extract) and lists **PMs with resolved Linux paths** (`platform_linux_command` — Windows/interop `/mnt/*` shims ignored). Missing PMs get recipes; Enter re-check / continue / skip / quit. `-y` / non-TTY: tips + continue. Then installs unless `--skip-reinstall`. **Failures are skipped** (never abort the run); each fail keeps a `/tmp` log + error line; end summary lists OK / Skipped / Failed with reasons (`reinstall_report_lines`). **pnpm/npm workspace roots** pre-check member packages (`workspace:*` + globs) — missing members skip with reason instead of a late `ERR_PNPM_WORKSPACE_PKG_NOT_FOUND`. PM output quiet unless `-v`. Corepack/npm forced non-interactive (`CI=1`, `COREPACK_ENABLE_DOWNLOAD_PROMPT=0`). `-y` = all projects; TTY picker v2 = `e`/`i`/`p`/`g`/`f`/`n`/`u`/`q` (Enter=all); `--ask` forces interactive pick + overwrite confirms. PM/tool lists auto-truncate via `lib/constraints/list.sh` (default top 10, `-F`/`-T`). `--reinstall-only` = manifest extract + installs (no home re-copy).

**Phase 11 (restore UX):** Ctrl+C/Z parity inside the reinstall batch. Each project runs under `linuxbkup_op_begin "reinstall-<pm>"` (can_skip=1) + `linuxbkup_without_monitor`. Menu: `r` re-run same project · `s` skip · `c` keep partial + next · `q` **soft-quit batch** (`LINUXBKUP_INTERRUPT_SOFT_QUIT=1` — partial summary, logs kept, no `exit 130`). Ctrl+Z = `safety_on_tstp` process-group STOP (same as backup). Failure-first re-run after summary. **Layout:** `lib/backup/reinstall.sh` thin barrel → `lib/backup/reinstall/{manifest,pm,preflight,select,run_one,run}.sh` (R1).

**Phase 12 (reinstall hardening):** archive `--reinstall-only` extract is prefix-tolerant (`./packages` vs `packages` via `reinstall_archive_pkg_prefix` / `reinstall_extract_manifest`). Picker counts no longer crash on multi-PM. pnpm installs run non-interactive with `--config.dangerouslyAllowAllBuilds=true` + env (`npm_config_dangerously_allow_all_builds=true`). Nested workspace members are **not** separate reinstall rows (`node_filter_reinstall_rows` collapses to workspace root); one root `pnpm i` installs the whole tree. Missing workspace **sources** on disk → clear skip (“run a full restore first”), not a late pnpm error. `reinstall_interrupt_boundary` runs before each project (soft-quit-safe). Progress `[i/N]`; OK logs quiet unless `-v`. Plan folded: shipped phase 12 (see [`../shipped/`](../shipped/)).

## Stage paths (shipped — phase 13 A)

- Shared helper: `compat_stage_path` in `lib/core/compat/compat.sh` (backup `linuxbkup.<pid>.<rand>`; restore/verify `linuxbkup-<kind>-<ts>.<pid>` under `-S` parent or `${TMPDIR:-/tmp}`).
- `backup -k` / `restore -k` / `verify` always print the path via `ui_kv_path`.
- Restore without `-k` logs extract path for the run; EXIT removes unless kept.

## Still missing

- Python / Go / mise reinstall arrays in the same JSON
- APT package reinstall (manifests only today)
- Privileged `/etc` restore UX beyond “skip if not writable” / sudo
- Real iSH/Termux/Kali soak (hardware) — checklist in `maintainer/temp/13-soak-checklist.md`

## Redesign target

SCAN → CLASSIFY → REPORT unexpected → DECIDE → RECLAIM/SECRET → SPACE → STAGE → schema → checksum → `tar.zst`.

Track: [`../phases/redesign.md`](../phases/redesign.md).
