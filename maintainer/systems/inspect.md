# System — inspect

Command: `linuxbkup inspect`. `--print-plan` shows only the home classification plan (same as `backup --print-plan`).

## Sources (live)

| Module | Role |
|--------|------|
| `lib/env/distro.sh` | os-release, arch, WSL kind/name when present |
| `lib/env/users.sh` | `/home/*`, `--user` / current |
| `lib/env/capabilities.sh` | pkg managers, tool managers, services, web, DBs, containers/cloud, languages, backup tools |
| `lib/fs/sizes.sh` | `du` targets + large home dirs (**filter stack**) |
| `lib/classify/*` | Full-home shallow plan (known / secret / skip / unexpected) |
| `lib/core/platform/paths.sh` | default archive dest preview |
| `lib/core/context.sh` | banner + required tools (`du`, `find`) |

Read-only. Supports `--include` / `--exclude` / `--no-defaults` / `-F` / `-T` / `--print-plan` / `--json` / `-v`.
