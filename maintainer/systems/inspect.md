# System — inspect

Command: `wslbkup inspect`

Sources:

- `lib/env/distro.sh` — os-release, arch, WSL kind/name
- `lib/env/users.sh` — `/home/*` listing, `--user` / current default
- `lib/env/capabilities.sh` — package managers, services, languages, backup tools
- `lib/fs/sizes.sh` — `du` targets + large home dirs
- `lib/classify/paths.sh` — uses `lib/constraints/*`
- `lib/windows/paths.sh` — default `…/Downloads/wslbkup/` preview
- `lib/core/context.sh` — banner + required tools (`du`, `find`)

Read-only. No filesystem modifications. Supports `--include`/`--exclude`/`--no-defaults`/`-F`/`-T`.
