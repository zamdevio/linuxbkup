# System — constraints

Source of truth for built-in path lists, listing policy, and the **filter stack**. Redesign phase **02** turns include discovery into full-`$HOME` scan + unexpected reporting — see [`../phases/02-home-scan-classify.md`](../phases/02-home-scan-classify.md).

| File | Role |
|------|------|
| `lib/constraints/base.sh` | Merge defaults + `--include` / `--exclude` / `--no-defaults` |
| `lib/constraints/filter.sh` | Shared `du`/scan exclude args (regenerable + simple user excludes) |
| `lib/constraints/list.sh` | `-F/--full`, `-T/--top` (default 10) |
| `lib/constraints/size_targets.sh` | `du` target templates |
| `lib/constraints/regenerable.sh` | Regeneratable paths, EREs, `CONSTRAINTS_DU_EXCLUDE_GLOBS` |
| `lib/constraints/important.sh` | Portable important paths (XDG / shell — no host dirnames) |
| `lib/constraints/secrets.sh` | Sensitive paths (presence only) |
| `lib/constraints/backup_paths.sh` | Default backup include templates (portable) |

## Rules

- User `--exclude` always wins.
- `--include` adds path templates / regex keeps.
- `--no-defaults` clears built-ins.
- **No host-shaped home dirnames** in shipped lists (`Projects` / `Workers` / `Tools` / …). Extra trees: `--include` until phase 02.
- Sizing (`lib/fs/sizes.sh`) and rsync excludes share regenerable globs from `CONSTRAINTS_DU_EXCLUDE_GLOBS`.
