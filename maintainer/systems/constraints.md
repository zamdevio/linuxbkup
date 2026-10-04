# System — constraints

Source of truth for built-in path lists and listing policy.

| File | Role |
|------|------|
| `lib/constraints/base.sh` | Merge defaults + `--include` / `--exclude` / `--no-defaults` |
| `lib/constraints/list.sh` | `-F/--full`, `-T/--top` (default 10) |
| `lib/constraints/size_targets.sh` | `du` target templates |
| `lib/constraints/regenerable.sh` | Regeneratable paths + EREs |
| `lib/constraints/important.sh` | Important user/app data |
| `lib/constraints/secrets.sh` | Sensitive paths (presence only) |

User `--exclude` always wins. `--include` adds path templates / regex keeps. `--no-defaults` clears built-ins.
