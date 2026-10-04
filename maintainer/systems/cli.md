# System — CLI

Surface: root **`linuxbkup`** bin. Env: `LINUXBKUP_*`.

## Flow

1. Parse global flags — `lib/core/common.sh`
2. Terminal UI — `lib/core/terminal/{style,links,control}.sh`
3. Safety — `lib/core/safety.sh`
4. Help/version — `lib/core/help.sh`
5. Platform (when needed) — `lib/core/platform/` via commands
6. Dispatch — `lib/cmd/<name>.sh` via `linuxbkup_cmd_<name>`

## Commands (live)

| Command | State |
|---------|--------|
| `inspect` | Live |
| `backup` | Live v1 (allowlisted paths) |
| `verify` | Live for `*.tar.zst` only |
| `deps` | Live |
| `list` | Thin / early |
| `restore` | Stub |

## Global flags (today)

Typical: `--dry-run`, `--yes` / `-y`, `--force-overwrite`, path filters (`--include` / `--exclude` / `--no-defaults`), `-F`/`-T`, `-o`/`--output` where wired.

## Redesign (not live)

See [phase 03](../phases/03-profiles-ask-flags.md): `--profile`, `--ask` (wins over `--yes`), `--print-plan`, `--keep-stage`, `--stage-dir`, `--json`, reclaim/secret flags.
