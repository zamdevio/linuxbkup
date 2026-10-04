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

Home/config from **full-home classification**. Decisions: `--ask` interactive (unexpected + large); `--yes` uses profile large defaults; non-TTY ≈ `--yes`. Regenerables skipped (rsync filter stack + expanded language/framework globs). Per-directory `.gitignore` honored unless `--no-gitignore`. Backup prints shared **environment snapshot** (`lib/env/snapshot.sh`) before staging. `-k/--keep-stage` / `-S/--stage-dir` control staging lifecycle.

## Stub / missing

- `restore` — not Near-full
- Restore decrypt for `secrets.tar.age` (phase 04.5)
- `schema.json` + decisions log (phase 05)
- Space preflight (phase 05)
- Multi-PM capture beyond APT (after 08.8 snapshot UI)

## Redesign target

SCAN → CLASSIFY → REPORT unexpected → DECIDE → RECLAIM/SECRET → SPACE → STAGE → schema → checksum → `tar.zst`.

Track: [`../phases/redesign.md`](../phases/redesign.md).
