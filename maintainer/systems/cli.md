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

Short aliases on frequent flags (one row each in `--help`):

| Short | Long |
|-------|------|
| `-y` | `--yes` |
| `-a` | `--ask` (wins over `--yes`) |
| `-p` | `--profile` easy\|balanced\|strict |
| `-n` | `--dry-run` |
| `-k` | `--keep-stage` |
| `-S` | `--stage-dir` |
| `-m` | `--max-size` |
| `-r` / `-R` | `--reclaim` / `--reclaim-all` |
| `-i` / `-e` | `--include` / `--exclude` |
| `-j` | `--json` |
| `-f` | `--force-overwrite` |
| `-o` `-u` `-v` `-d` `-q` `-F` `-T` | output / user / verbose / debug / quiet / full / top |

Long-only (less frequent / dangerous): `--no-secrets`, `--secrets-plain`, `--no-defaults`, `--no-gitignore` (`--no-gitignores`), `--mark-secret`, `--no-color`, `--no-links`.

Default copy honors per-directory `.gitignore` (rsync dir-merge) plus regenerable strip (`node_modules`, `.next`, caches, …).

Ask UI: `lib/ask/select.sh` (numbered + optional fzf).
