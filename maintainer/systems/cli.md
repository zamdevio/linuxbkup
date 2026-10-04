# System — CLI

Surface: root **`linuxbkup`** bin. Env: `LINUXBKUP_*`.

## Flow

1. Parse global flags — `lib/core/common.sh` (+ `lib/core/profile.sh` ask>yes)
2. Terminal UI — `lib/core/terminal/{style,links,control,progress,notify}.sh`
3. Safety — `lib/core/safety.sh`
4. Help/version — `lib/core/help.sh`
5. Platform (when needed) — `lib/core/platform/` via commands
6. Dispatch — `lib/cmd/<name>.sh` via `linuxbkup_cmd_<name>`

## Commands (live)

| Command | State |
|---------|--------|
| `inspect` | Live |
| `plan` | Live (+ `--json`) |
| `backup` | Live (classify → stage → checksum → tar.zst) |
| `verify` | Live for archive **or** staging |
| `deps` | Live |
| `list` | Thin / early |
| `restore` | Stub |

## Global flags (today)

`--dry-run`, `-y/--yes`, `--ask` (wins over `--yes`), `--profile easy|balanced|strict`, `--keep-stage`, `--stage-dir`, `--max-size`, `--force-overwrite`, `--include` / `--exclude` / `--no-defaults`, `-F`/`-T`, `-o`/`--output`, `-v`/`-d`, `--json`.

Ask UI: `lib/ask/select.sh` (numbered + optional fzf).
