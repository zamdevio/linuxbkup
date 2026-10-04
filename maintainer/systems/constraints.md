# System — constraints + classify

Built-in **rules**, listing policy, and the **filter stack**. Phase **02** full-`$HOME` scan is live.

| File | Role |
|------|------|
| `lib/constraints/base.sh` | Merge + `--include` / `--exclude` / `--no-defaults` |
| `lib/constraints/rules.sh` | Portable class rules (include/skip/local/etc) |
| `lib/constraints/filter.sh` | Shared `du`/scan exclude args |
| `lib/constraints/list.sh` | `-F/--full`, `-T/--top` |
| `lib/constraints/size_targets.sh` | Inspect filesystem target templates |
| `lib/constraints/regenerable.sh` | Regeneratable EREs + `CONSTRAINTS_DU_EXCLUDE_GLOBS` |
| `lib/constraints/important.sh` | Legacy important templates (inspect-adjacent) |
| `lib/constraints/secrets.sh` | Sensitive paths (presence only) |
| `lib/constraints/backup_paths.sh` | Legacy templates (superseded by rules + scan) |
| `lib/classify/scan.sh` | Shallow home scan → TSV plan rows |
| `lib/classify/plan.sh` | Human plan printer |
| `lib/classify/paths.sh` | Inspect entry → same plan |

## Rules

- User `--exclude` always wins. Path-like tokens expand `~` / `{home}` against the active `--user` home, strip trailing `/`, and match exact/prefix/basename — not naive ERE (so `.` in paths is literal).
- Unexpected paths: report always; `--yes` / non-TTY → include; TTY backup asks.
- **No host-shaped home dirnames** in shipped rules.
- Sizing / rsync share regenerable globs from `CONSTRAINTS_DU_EXCLUDE_GLOBS` (node_modules, .next, caches, build/dist, language tool stores, …).
- Rsync also applies per-directory `.gitignore` via `--filter=':- .gitignore'` unless `--no-gitignore`.
- `plan` / dry-run skip per-path `du` unless `-v`.
- Top-level `go` (GOPATH) default **skip** — regenerable cache; `--include` / phase 04 reclaim to pull back.
- `/tmp` is **not** a default inspect size target (no special classify rule — simply omitted).
- `--max-size` limits **uncompressed staging** footprint (see terminal UX / backup).
