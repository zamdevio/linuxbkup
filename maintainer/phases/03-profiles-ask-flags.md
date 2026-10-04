# Phase 03 — Profiles, ask UI, flags

**Goal:** `--profile`, rich Bash ask UI (fzf optional), and planning/ops flags. Safety + user choice.

## Profiles

| Profile | Large dir | Large file | Suggested when asking | Under `--yes` only |
|---------|-----------|------------|------------------------|--------------------|
| `easy` | 2 GiB | 500 MiB | backup | include large |
| `balanced` | 500 MiB | 100 MiB | backup | include large |
| `strict` | 100 MiB | 50 MiB | skip | exclude large |

Default profile: **`balanced`** (portable + reasonably safe). Document that `strict` is the “paranoid size” mode.

## Flag precedence

```text
--ask present + --yes present
  → log: "ignoring --yes because --ask is set"
  → interactive (--ask wins)

--ask
  → prompt unexpected + large (+ reclaim/secret steps as implemented)
  → profile only sets *suggested* default; user choice wins

--yes (no --ask)
  → unexpected auto-include; large by profile table; no prompts

non-TTY without --ask/--yes
  → same as --yes for decisions (script-safe); or require --yes — pick one in impl and document.
  Locked preference: treat non-TTY like --yes for include/skip defaults (log that).
```

## Ask UI without fzf (required)

```text
Large / unexpected items  (profile: strict — suggested: skip)
  [1] ~/.local/custom-dir    420M  unexpected   suggested: skip
  [2] ~/data/archive         1.1G  large        suggested: skip

Select to BACKUP (others keep suggestion):
  numbers / ranges  e.g. 1,2 or 1-2
  a = backup all · n = backup none · Enter = accept suggestions
  i <n> = inspect · q = abort
>
```

Optional **fzf** multi-select if installed (`linuxbkup deps install fzf`). Same semantics.

## Commands / flags (locked in)

| Item | Behavior |
|------|----------|
| `plan` | Dedicated command: include/skip/secret/unexpected table (no writes). `-F`/`-T` apply. |
| `plan --json` | Stable `linuxbkup.plan/v1` JSON envelope on stdout |
| `backup` | Always runs for real (or `--dry-run`); ends with short summary + tip to run `plan` |
| `-v` / `--verbose` | Human detail (sizes, progress) |
| `-d` / `--debug` | Forensic why/commands on stderr (implies `-v`) |
| `--keep-stage` | Do not delete staging after successful pack |
| `--stage-dir <path>` | Staging root (space planning / tmpfs / big disk) |

Also: `--exclude` / `--include`, `--no-dotfiles` / `--only-dotfiles`, `-o/--output`.

**Removed:** `--print-plan` (use `plan`).

## Permission policy (locked)

- **Never auto-sudo** for reading/copying files.
- Unreadable / partial rsync (`rc` 23/24): soft-skip, WARN, continue.
- `--yes` / non-TTY: auto soft-skip.
- TTY: ask once (“skip further denials?”); then skip-all for the run.
- Package install guides may show `sudo` — that is install-only, not backup runtime.

## Slices

- [x] **03.1** Parse `--profile`, `--ask`, `--yes`; implement ask>yes log line
- [x] **03.2** Bash multi-select module under `lib/ask/select.sh`
- [x] **03.3** Optional fzf path when present (`guides/tools/fzf.guide` required)
- [x] **03.4** `plan` + `plan --json` envelope (landed pre-03)
- [x] **03.5** `--keep-stage` / `--stage-dir` wired through backup
- [x] **03.6** Help + generic examples
- [x] **03.7** Smoke: ask>yes precedence; `plan` never writes

## Acceptance

- `linuxbkup backup --ask --yes` logs ignore and prompts
- Strict + `--ask` can still backup a “suggested skip” large path
- Zero-fzf install still fully usable
- `linuxbkup plan` never writes an archive; `backup` does not hijack into plan-only mode

## After ship

`systems/cli.md`, `systems/backup-restore.md`, `shipped/`.
