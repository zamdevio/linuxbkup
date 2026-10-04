# System — inspect

Command: `linuxbkup inspect`.

## Sources (live)

| Module | Role |
|--------|------|
| `lib/env/distro.sh` | os-release, arch, WSL kind/name when present |
| `lib/env/users.sh` | `/home/*`, `--user` / current |
| `lib/env/capabilities.sh` | pkg managers, tool managers, services, web, DBs, containers/cloud, languages, backup tools |
| `lib/fs/sizes.sh` | `du` targets + large home dirs (**filter stack**) |
| `lib/classify/paths.sh` | uses `lib/constraints/*` |
| `lib/core/platform/paths.sh` | default archive dest preview |
| `lib/core/context.sh` | banner + required tools (`du`, `find`) |

Read-only. Supports `--include` / `--exclude` / `--no-defaults` / `-F` / `-T`.

## Redesign

Phase **02** expands classify to full-home + unexpected reporting; `inspect` should preview the same plan as `backup --print-plan`.
