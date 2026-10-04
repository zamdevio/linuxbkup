# System — backup / restore

## Live today

| Piece | Path / behavior |
|-------|-----------------|
| Backup cmd | `lib/cmd/backup.sh` |
| Staging / home copy | `lib/backup/` |
| Pack + checksums | `lib/archive/` |
| APT manuals | `modules/apt.sh` (and backup orchestration) |
| Default dest | Windows Downloads via `lib/windows/` when available |
| Verify | `lib/cmd/verify.sh` — **archive file only** (`*.tar.zst`) |
| Failure UX | Staging kept if pack fails; INDEX write hardened (`32b5b11`) |

Home/config paths still come largely from **constraints allowlists**, not a full `$HOME` scan.

## Stub / missing

- `restore` — not Near-full
- Secrets/`age` encrypt pipeline
- `schema.json` + decisions log
- Verify against **staging directories**
- Space preflight
- Profiles / ask / reclaim

## Redesign target

SCAN → CLASSIFY → REPORT unexpected → DECIDE → RECLAIM/SECRET → SPACE → STAGE → schema → checksum → `tar.zst`.

Track: [`../phases/redesign.md`](../phases/redesign.md) phases **01–05**. Docs site: **06–07**.
