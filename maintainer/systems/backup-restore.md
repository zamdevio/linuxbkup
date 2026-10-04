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
| Failure UX | Staging kept if pack fails; INDEX write hardened (`32b5b11`) |

Home/config defaults are **portable allowlists** (shell/dotfiles, `.config`, `.local/bin`, `.ssh`); full `$HOME` scan is phase **02**. Extra trees: `--include`.

## Stub / missing

- `restore` — not Near-full
- Secrets/`age` encrypt pipeline
- `schema.json` + decisions log
- Space preflight
- Profiles / ask / reclaim

## Redesign target

SCAN → CLASSIFY → REPORT unexpected → DECIDE → RECLAIM/SECRET → SPACE → STAGE → schema → checksum → `tar.zst`.

Track: [`../phases/redesign.md`](../phases/redesign.md) phases **02–05**. Docs site: **06–07**.
