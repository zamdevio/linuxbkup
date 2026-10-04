# System — inspect

Command: `wslbkup inspect` (→ `linuxbkup inspect` after phase 00).

## Sources (live)

| Module | Role |
|--------|------|
| `lib/env/distro.sh` | os-release, arch, WSL kind/name when present |
| `lib/env/users.sh` | `/home/*`, `--user` / current |
| `lib/env/capabilities.sh` | package managers, services, languages, backup tools |
| `lib/fs/sizes.sh` | `du` targets + large home dirs |
| `lib/classify/paths.sh` | uses `lib/constraints/*` |
| `lib/windows/paths.sh` | default Downloads preview when mount exists |
| `lib/core/context.sh` | banner + required tools (`du`, `find`) |

Read-only. Supports `--include` / `--exclude` / `--no-defaults` / `-F` / `-T`.

## Redesign

Phase **02** expands classify to full-home + unexpected reporting; `inspect` should preview the same plan as `backup --print-plan`. Platform dest defaults move under `lib/core/platform/` (phase **00**).
