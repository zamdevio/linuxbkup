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

**Fail-fast (phase 09):** secrets mode + disk floor checked in Preflight **before** snapshot/copy; passphrase required under `--yes` before any heavy work. Estimates use byte-accurate filtered `du` (not summed `du -sh` labels). Space gate (`lib/backup/preflight.sh`) re-checks with estimate+10% before rsync confirm.

Backup prints shared **environment snapshot** (`lib/env/snapshot.sh`) after preflight. `-k/--keep-stage` / `-S/--stage-dir` control staging lifecycle.

Long steps (`classify`, `copy`, `checksum`, `pack`, …) use `linuxbkup_op_begin` + `linuxbkup_interrupt_resolve` (see [`cli.md`](./cli.md)). Copy goes through `backup_handle_interrupt` after `backup_rsync_run`.

## Stub / missing

- `restore` — stub (op state only; no real extract yet)
- Restore decrypt for `secrets.tar.age` (phase 04.5)
- Multi-PM capture beyond APT (after 08.8 snapshot UI)

## Redesign target

SCAN → CLASSIFY → REPORT unexpected → DECIDE → RECLAIM/SECRET → SPACE → STAGE → schema → checksum → `tar.zst`.

Track: [`../phases/redesign.md`](../phases/redesign.md).
