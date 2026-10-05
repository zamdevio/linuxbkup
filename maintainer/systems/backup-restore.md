# System — backup / restore

## Live today

| Piece | Path / behavior |
|-------|-----------------|
| Backup cmd | `lib/cmd/backup.sh` |
| Staging / home copy | `lib/backup/` |
| Pack + checksums | `lib/archive/` |
| Verify helpers | `lib/archive/verify.sh` |
| APT manuals | `modules/apt.sh` (and backup orchestration) |
| Default dest | `lib/core/platform/paths.sh` — native `~/Backups/linuxbkup/` or Windows Downloads when mounted |
| Verify | `lib/cmd/verify.sh` — **archive** (`*.tar.zst`) **or staging directory** with `checksums.sha256` |
| Profiles / ask | `lib/core/profile.sh` + `lib/ask/select.sh` |
| Failure UX | Staging kept if pack fails; INDEX write ignores `find\|head` SIGPIPE |

Home/config from **full-home classification**. Decisions: `--ask` interactive (unexpected + large); `--yes` uses profile large defaults; non-TTY ≈ `--yes`. Regenerables skipped (rsync filter stack + expanded language/framework/PM globs + `*.pyc` etc.). Per-directory `.gitignore` honored unless `--no-gitignore`.

**Fail-fast (phase 09):** secrets mode + disk floor checked in Preflight **before** snapshot/copy; passphrase required under `--yes` before any heavy work. Preflight banner shows profile / gitignore / max-size / secrets at a glance (`backup_preflight_banner`). Backup prints `ui_step` labels: preflight → detect → capture → stage → seal → pack → summary. Estimates use byte-accurate filtered `du`. Space gate (`lib/backup/preflight.sh`) re-checks with estimate+10% before rsync confirm.

Backup prints shared **environment snapshot** (`lib/env/snapshot.sh`) after preflight. `-k/--keep-stage` / `-S/--stage-dir` control staging lifecycle.

Long steps (`classify`, `copy`, `secrets`, `index`, `checksum`, `pack`, `summary`, …) use `linuxbkup_op_begin` + `linuxbkup_interrupt_resolve` (see [`cli.md`](./cli.md)). Copy/pack long waits run under `linuxbkup_without_monitor` so tty Ctrl+C cannot skip the menu via a child-only process group.

## Restore (live)

`lib/cmd/restore.sh` + `lib/backup/restore_files.sh` + `lib/backup/secrets_crypt.sh`:

1. Extract archive (or use staging) → schema soft-check  
2. Decrypt `secrets.tar.age` when present  
3. Rsync `home/` + `secrets/` → `$HOME`; `config/etc` → `/etc` if writable  
4. Overwrite gate: existing files require `-f/--force-overwrite` (`--yes` alone is never enough)

## Still missing

- Multi-PM capture / package reinstall beyond APT manifests
- Privileged `/etc` restore UX (sudo path) beyond “skip if not writable”

## Redesign target

SCAN → CLASSIFY → REPORT unexpected → DECIDE → RECLAIM/SECRET → SPACE → STAGE → schema → checksum → `tar.zst`.

Track: [`../phases/redesign.md`](../phases/redesign.md).
