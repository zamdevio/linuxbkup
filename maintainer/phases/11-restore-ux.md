# Phase 11 — restore UX: interrupt parity + project picker

**Goal:** Make `restore` (esp. the **reinstall slice**) as interruption-safe and pick-friendly as `backup`, and give users with **tens of Node projects** a picker they can actually use.

**Status:** **landed** (product + smoke + docs). Layout: `lib/backup/reinstall.sh` barrel → `lib/backup/reinstall/*.sh` (R1). Soak on a real 100+ project restore still recommended.

## Why now

- `backup` has full Ctrl+C/Ctrl+Z coverage; `restore` does not.
- Reinstall batch runs 100+ `pnpm i` / `npm ci` sequentially; users need to **pause / retry / skip / quit** mid-run, not only at project pick time.
- The current picker (`a` / `n` / `1-3` / `f` fzf) is awkward for “skip these few, keep everything else” at 140 projects.
- Real run above shows exactly the pain: after a few OKs the run hangs at `^C` with no menu — user wants to retry / skip / continue.

## Doctrine

| Rule | Detail |
|------|--------|
| One interrupt API | Reuse `lib/core/interrupt.sh` + `safety.sh` — **no per-command reimplementation**. |
| Parity with backup | All of `restore`: extract → secrets → files → reinstalls → summary, same menu keys (`r` retry / `s` skip / `c` continue / `q` quit / `x` quit+cleanup). |
| Pause = safe | Ctrl+C **pauses the batch** (menu), never silently kills or corrupts a project mid-install. |
| Refined picker | Default = **skip-none (all)**, then action modes: exclude-by-index (default), include-only, PM filter, tag/grep filter, fzf when available. |
| Failure-first | Failed projects are listed up-front on re-run with reasons + log paths so users can act (reinstall-only again, fix source, skip permanently). |
| `--skip-reinstall` | Keeps meaning “none” — no ambiguity with the picker. |
| Non-TTY / `-y` | Skips picker + menu (batch all, fail report at end). Already true. |

## Ctrl+C / Ctrl+Z parity

Target behavior map (per op inside `restore`):

| Op | Retry (`r`) | Skip (`s`) | Continue (`c`) | Quit (`q`) |
|----|-------------|------------|----------------|------------|
| extract (archive) | re-run `tar` | skip extract (fatal if staged absent) | resume (same as retry when partial unsafe) | keep stage, exit |
| secrets decrypt | re-run age | skip decrypt (no secrets) | same as retry | exit |
| files home/secrets | re-run rsync | keep partial + continue | same as retry | exit |
| **reinstall run** | **re-run `pnpm i` / `npm ci` in same dir** | **mark skip, continue next project** | **keep partial node_modules, continue next** | **exit batch, keep logs, print report** |
| reinstall report | — | — | — | exit |

**Reinstall slice specifics (target):**

- Each project: `linuxbkup_op_begin "reinstall-<pm>" "<dir>"` + `linuxbkup_without_monitor` (C = always enabled inside install).
- Ctrl+C mid-install → SIGINT to the child PM (pnpm cleans up), then menu.
- `r` → re-run the same project (fresh `log_file`, discard partial).
- `s` / `c` → record `REINSTALL_LAST_REASON="interrupted (skip/continue)"`, move to next project; `s` vs `c` same outcome but different report tag.
- `q` → stop the batch now; print “paused — re-run to finish”, keep `/tmp` logs, show partial **Reinstall summary**.
- Ctrl+Z (SIGTSTP) → full job-control suspend (same as backup): `STOP` the process group, `fg`/`bg` to resume; cursor restored, live row parked.
- Second Ctrl+C in the menu → force-quit (matches backup).

**Smoke additions (when implemented):**

- `LINUXBKUP_TEST_INTERRUPT_REPLY=r` + SIGINT during fake PM → project retried, batch continues.
- `LINUXBKUP_TEST_INTERRUPT_REPLY=s` + SIGINT → skipped with reason, next project runs.
- `repl=q` → batch stops, partial summary printed, exit code set.
- Ctrl+Z suspend/resume on a sleep-based fake PM.

## Project picker v2

Goal: **pick less, keep all; exclude few, include some, filter by PM/label.**

### Interaction flow (TTY, `--ask` or plain TTY)

```
Reinstall preflight
  · Checked reinstalls.tsv — 140 projects (npm 18, pnpm 122)
  · Ready: ✓ npm ✓ pnpm (Linux)
  · Missing: none

Reinstall — pick projects
  All 140 selected. Action:
    [a]ll (current)  [e]xclude some  [i]nclude only  [p]M filter
    [g]rep path filter  [f]fzf  [n]one  [q]skip step
  > e

  Exclude — numbers/ranges (1,2,5-9), or names/tags:
  > 3,7,12-15

  137 of 140 selected (npm 16, pnpm 121). [Enter] run · [u]ndo · [q]back
  >
```

### Rules

| Input | Meaning |
|-------|---------|
| `a` / Enter | all (default) |
| `e` | exclude mode: list indices/ranges — everything else stays selected |
| `i` | include-only mode: only listed indices are selected |
| `p` | PM filter: `pnpm` / `npm` / `yarn` / `bun` — toggle whole PM groups |
| `g` | substring/regex path filter (“workers” → select only matching) |
| `f` | fzf multi-select (default when list > 20 and fzf present) |
| `n` | none |
| `q` | skip step / back |
| `u` | undo last mode (return to previous selection) |

### Defaults & shortcuts

- **Enter = all** (current behavior — stays).
- Numbers typed directly = **exclude** when in `e`, include-only when in `i`.
- `1-3`, `1,2,4-6`, `-7` (exclude up to 7) supported by `ask_parse_selection`.
- `-T/--top` already truncates the display; **selection still applies to all** (never mis-truncate silents).
- PM counts shown beside each line (`[1] pnpm  Workers/mailer (pnpm i)`).

### Report & re-run loop (target)

```
Reinstall summary
  OK       133
  Skipped    3   (interrupted / missing member)
  Failed     4   (log paths + first error line each)

Failed projects (skipped — re-run later)
  Learning/cyber       ERR_PNPM_IGNORED_BUILDS
  Projects/NextGen/…   workspace member missing: @nextgen/db
[Enter] re-run all failed only   ·  [p] pick again  ·  [q] quit
```

- Re-run-failed-only: `linuxbkup -y --reinstall-only` internally filtered to `failed` set (or a new `--failed-only`-style hint, decided at implementation).

## Docs to touch on implementation

- `lib/core/help.sh` restore screen: Ctrl+C/Z menu + picker modes
- `docs/cli.md` Restore section: Reinstalls + Signals
- `maintainer/systems/cli.md` signal table + restore row
- `maintainer/systems/backup-restore.md` reinstall para
- `maintainer/shipped/README.md` row

## Acceptance

- Ctrl+C during a real `pnpm i` shows the menu; `r` retries, `s`/`c` move on, `q` stops with partial report. Ctrl+Z suspends/resumes cleanly.
- Exclude/include/PM/grep modes produce the same result set as manual indices.
- No console corruption (live line parked, cursor restored).
- Smoke covers all menu keys + filler modes.

## After ship

- Fold outcome into `systems/cli.md` + `backup-restore.md` + `shipped/`.
- Consider reusing the picker for `backup --ask` path decisions later.

Umbrella: [`redesign.md`](./redesign.md). Focus: [`focus.md`](./focus.md). Layout split tracked in [`refactor.md`](./refactor.md).
