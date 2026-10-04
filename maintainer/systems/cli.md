# System — CLI

Surface: root **`linuxbkup`** bin. Env: `LINUXBKUP_*`.

## Flow

1. Parse global flags — `lib/core/common.sh` (+ `lib/core/profile.sh` ask>yes)
2. Terminal UI — `lib/core/terminal/{style,links,control,progress,notify}.sh`
3. Safety + interrupt — `lib/core/safety.sh` + `lib/core/interrupt.sh`
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
| `-w` | `--workers` (cap for parallel checksums; default 4, auto 1–N by job size) |
| `-f` | `--force-overwrite` |
| `-o` `-u` `-v` `-d` `-q` `-F` `-T` | output / user / verbose / debug / quiet / full / top |

Long-only (less frequent / dangerous): `--no-secrets`, `--secrets-plain`, `--no-defaults`, `--no-gitignore` (`--no-gitignores`), `--mark-secret`, `--no-color`, `--no-links`.

Default copy honors per-directory `.gitignore` (rsync dir-merge) plus regenerable strip (`node_modules`, `.next`, caches, …).

Ask UI: `lib/ask/select.sh` (numbered + optional fzf).

## Signals — central interrupt API

**Keep** the Ctrl+C pause→menu system. One module owns it: `lib/core/interrupt.sh` (+ traps in `lib/core/safety.sh`).

| Helper | Role |
|--------|------|
| `linuxbkup_op_begin` / `op_item` / `op_end` | Mark current step/item for the menu |
| `linuxbkup_interrupt_resolve` | **Central:** pending? → menu if needed → apply → set `LINUXBKUP_INTERRUPT_RESULT` |
| `linuxbkup_interrupt_disarm` / `arm` | Ignore / restore SIGINT (teardown + retry setup) |
| `linuxbkup_without_monitor` | Run blocking work with `set +m` so tty ^C hits our trap |
| `linuxbkup_interrupt_shield` | Defer INT around short critical `$()` (e.g. dest resolve) |
| `linuxbkup_tty_restore` | `tput cnorm` + unhide cursor on EXIT |

Ops only: `op_begin` → work → `if linuxbkup_interrupt_resolve; then case RESULT…`. Do **not** call menu/apply by hand or wrap apply in `$()`.

**Whole-backup coverage:** setup → resolve → snapshot → apt → classify → copy → secrets → index → checksum → pack → summary. Long waits (`rsync`, `tar|zstd`, checksum workers) use `without_monitor` / `set +m` so Ctrl+C cannot skip the menu via a child-only PGID.

**Resume rule:** after menu/resolve, SIGINT stays ignored until the next `op_begin` / `backup_rsync_run` / pack arm — otherwise `set -m` job teardown re-raises INT and kills the shell mid-retry.

**Smoke proof:** `LINUXBKUP_TEST_INTERRUPT_REPLY=r` + SIGINT during `without_monitor sleep` → resolve RESULT=retry → process survives.

## Ctrl+C (SIGINT)

Never silent “Continuing…”. Trap stops children (rsync/du/workers), then menu:

| Choice | Behavior |
|--------|----------|
| `r` | Retry last op (overwrite partial / re-scan) |
| `s` | Skip current item (copy only) |
| `c` | Continue — or same as retry when partial results are unsafe (classify/checksum/pack/copy) |
| `q` | Quit (keep staging) |
| `x` | Quit + remove staging |

`rsync` rc=20 is interrupt, never soft-skip. Classify/plan scans discard partial path lists and re-scan. Second Ctrl+C in the menu force-quits. Same handlers for `backup`, `restore`, `verify`, `plan`, `inspect`.

**Ctrl+Z (SIGTSTP):** real job-control suspend (not kill). Enables `set -m` (monitor mode) and `STOP`s the **process group** so bash doesn’t stay wedged in `wait` while `rsync` is `T`. Parks the live line, shows the cursor, returns you to the shell. Resume: `fg` (or `bg`). Graceful abort stays on **Ctrl+C**.

## Live progress / cursor

- Progress paints on **stderr** with `\r` + erase-line (same pattern as i18nprune).
- Durable logs/`ui_*` **park** the live row first so scrollback stays clean.
- User Enter mid-bar may leave a blank row; the next update clears and repaints.
- Cursor hidden during the bar; always restored on end / interrupt / process exit.
- Command body runs under `set +e` so a handled Ctrl+C (status 130) does not abort after “Continuing…”.
