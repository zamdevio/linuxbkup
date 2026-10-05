# Refactor — layout & large-file split

**Goal:** Keep the Bash product **easy to maintain** by splitting oversized modules into focused subdirectories (`lib/backup/reinstall/*.sh`) — **codebase-wide**, not a one-off on `reinstall.sh`. Same for the test suite: `tests/smoke.sh` is past 1k lines → `tests/smoke/*.test.sh`.

**Status:** **open (parallel)** — pull slices alongside product Focus work; do not block Kali soak / docs on it. Pure structure — **no product behavior changes**.

## Doctrine (locked)

| Rule | Detail |
|------|--------|
| Bash-first | Still shell. No Node/Python runtime. No new framework. |
| Split by responsibility | One concern per file (manifest / PM resolve / preflight / picker / runner). Not alphabetical dumps. |
| Thin public barrel | Old entry path stays a **loader** that sources `lib/<area>/<name>/*.sh` in a fixed order. Call sites keep `source …/<name>.sh`. |
| Stable function names | Public helpers keep names (`reinstall_apply`, `tools_check`, …). Refactor moves code, does not rename APIs in the same slice. |
| Size budget | **Soft target ≤ 250 lines/file. Soft hard-cap 400.** Above cap → mandatory split in the next Focus touch. |
| Sourcing | `source "${LINUXBKUP_ROOT}/…"` + `# shellcheck source=…` on each line. Barrel sources children in explicit order (deps first). |
| Nameref rule | Always pass the caller's **variable name** into callees — never a local nameref alias (circular refs). |
| No magic PATH | Subdir files are **not** auto-discovered by the CLI. Only the barrel (or cmd script) sources them. Tests: runner sources `tests/smoke/*.test.sh` in numeric order only. |
| Verify each slice | `bash -n` every touched file + `./tests/smoke.sh` green before the next split. |
| Docs same day | After a landed split: `maintainer/systems/` path map + `shipped/` if user-facing paths change. |

## Target shape — product

```text
lib/backup/reinstall.sh          # thin barrel (loader only)
lib/backup/reinstall/
  manifest.sh                    # load tsv/json rows, peek from archive/stage
  pm.sh                          # Linux-only resolve, status lines, recipes, corepack
  preflight.sh                   # preflight guide + list policy rendering
  select.sh                      # project picker (TTY / fzf / -y / --ask)
  run.sh                         # run_one + reinstall_apply + fail report + workspace checks
```

Restore-related modules stay under `lib/backup/` (restore cmd keeps sourcing the barrels). Do **not** invent a parallel `lib/cmd/restore/*` tree unless a later slice proves cmd files exceed budget.

Barrel sketch (order matters):

```bash
# lib/backup/reinstall.sh
# shellcheck shell=bash
# Thin loader — split lives in lib/backup/reinstall/*.sh
_reinstall_dir="${LINUXBKUP_ROOT}/lib/backup/reinstall"
# shellcheck source=lib/backup/reinstall/manifest.sh
source "${_reinstall_dir}/manifest.sh"
# shellcheck source=lib/backup/reinstall/pm.sh
source "${_reinstall_dir}/pm.sh"
# shellcheck source=lib/backup/reinstall/preflight.sh
source "${_reinstall_dir}/preflight.sh"
# shellcheck source=lib/backup/reinstall/select.sh
source "${_reinstall_dir}/select.sh"
# shellcheck source=lib/backup/reinstall/run.sh
source "${_reinstall_dir}/run.sh"
```

Call sites (`lib/cmd/restore.sh`, smoke tests) keep:

```bash
source "${LINUXBKUP_ROOT}/lib/backup/reinstall.sh"
```

## Target shape — smoke suite

`tests/smoke.sh` is **~1200 lines** and will keep growing. Split into a thin runner + numbered suites. **Runner stays** `tests/smoke.sh` (same path CI / muscle memory).

```text
tests/smoke.sh                  # thin runner: helpers + source *.test.sh in order
tests/smoke/_lib.sh             # ok/bad/fail, ROOT/CLI, shared temp helpers
tests/smoke/01-cli.sh           # help, version, deps status, identity, unknown cmd
tests/smoke/02-plan.sh          # plan/--json, filters, max-size, classify, reclaim
tests/smoke/03-secrets.sh       # age encrypt/decrypt, secrets fail-fast
tests/smoke/04-reinstall.sh     # node capture, PM resolve, workspace, peek, preflight
tests/smoke/05-restore.sh       # restore files, sudo SUDO_USER, overwrite gates
tests/smoke/06-terminal.sh      # progress, interrupt/SIGINT, events.jsonl, workers
tests/smoke/07-archive.sh       # checksums, schema, decisions, compat probes
```

Runner sketch:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/smoke/_lib.sh
source "${ROOT}/tests/smoke/_lib.sh"
for t in "${ROOT}"/tests/smoke/[0-9][0-9]-*.sh; do
  [[ -f "${t}" ]] || continue
  # shellcheck source=/dev/null
  source "${t}"
done
# _lib.sh owns fail counter + final exit
smoke_finish
```

Rules for test files:

- Each `NN-*.test.sh` / `NN-*.sh` is **sourced**, not executed (shares `ok`/`bad`/`fail`).
- Prefix locals with the suite name (`_nd_`, `_rf_`, …) to avoid cross-suite clobber.
- No new behavior tests in the same commit as a pure move.
- `bash -n` every new file; runner must exit non-zero if any suite set `fail`.

## Inventory (today — wc -l, approximate)

Split when a slice is being touched **or** file is already over the soft cap:

| File | Lines | Suggested split |
|------|------:|-----------------|
| `tests/smoke.sh` | ~1195 | **R-SMOKE first** → `tests/smoke/*.sh` + thin runner |
| `lib/backup/reinstall.sh` | ~997 | `backup/reinstall/{manifest,pm,preflight,select,run}.sh` |
| `lib/backup/home.sh` | ~584 | `backup/home/{rank,rsync,copy}.sh` |
| `lib/cmd/backup.sh` | ~350 | keep cmd thin; push helpers into `backup/` |
| `lib/core/safety.sh` | ~337 | `core/safety/{confirm,overwrite,signals,rsync}.sh` |
| `lib/cmd/deps.sh` | ~306 | thin cmd + status/install helpers |
| `lib/backup/secrets_crypt.sh` | ~306 | `backup/secrets/{mode,age,crypt}.sh` |
| `lib/fs/sizes.sh` | ~298 | `fs/sizes/{parse,du,targets}.sh` |
| `lib/tools/check.sh` | ~287 | `tools/check/{resolve,guides,status}.sh` |
| `lib/constraints/regenerable.sh` | ~287 | `constraints/regenerable/{lists,filters}.sh` |
| `lib/core/help.sh` | ~279 | `core/help/{usage,commands}.sh` |
| `lib/core/interrupt.sh` | ~276 | `core/interrupt/{ops,menu,resolve}.sh` |
| `modules/node.sh` | ~258 | `modules/node/{detect,capture}.sh` |
| `lib/cmd/restore.sh` | ~239 | near budget; split only if it grows |
| `lib/core/common.sh` | ~238 | parse/globals vs helpers if it grows |
| `lib/core/terminal/progress.sh` | ~229 | leave unless touching |
| `lib/backup/restore_files.sh` | ~204 | leave unless touching |

Already-good directory examples: `lib/core/terminal/`, `lib/core/platform/`, `lib/classify/`.

## Slices (parallel Focus-sized; max 3 open at a time)

- [ ] **R-SMOKE.** `tests/smoke.sh` → `_lib.sh` + `01`–`07` suites + thin runner (same CLI path)
- [ ] **R1. reinstall split** — barrel + `lib/backup/reinstall/*.sh`; call sites still `…/reinstall.sh`
- [ ] **R2. backup/home split** — `home/{rank,rsync,copy}.sh`; barrel `lib/backup/home.sh`
- [ ] **R3. safety split** — confirm/overwrite vs signals/rsync; traps once via `linuxbkup_install_traps`
- [ ] **R4. secrets split** — mode resolution vs age encrypt/decrypt
- [ ] **R5. tools/check split** — resolve+list policy vs guides vs install
- [ ] **R6. interrupt split** — op lifecycle vs menu/resolve
- [ ] **R7. help split** — global usage vs per-command help text
- [ ] **R8. sizes/regenerable/node** — remaining soft-cap offenders
- [ ] **R9. cmd thin-out** — `backup.sh` / `deps.sh` / `restore.sh` orchestration only

**Order when opening parallel work:** **R-SMOKE → R1 → R2 → R3**. Smoke first so every later product split has a suite that still runs in pieces.

## Per-slice checklist

1. Read the file; group functions by responsibility.
2. Create target dir; move groups; leave **only** `source` lines in the old barrel (or thin runner for smoke).
3. `bash -n` barrel/runner + every child.
4. `./tests/smoke.sh` — no new FAILs (runner still one command).
5. `rg "source .*reinstall.sh"` (or the split name) — call sites unchanged unless a slice renames the entry (update smoke + cmds **in the same commit**).
6. Update `maintainer/systems/<area>.md` path table.
7. Update this phase’s slice checkbox + `roadmap.md` status.

## Anti-patterns (do not)

- Splitting into 20 files of 20 lines each “for cleanliness”
- Auto-`source` every `*.sh` in a product directory (order + side effects become magic)
- Executing each smoke file as a separate process in CI without the shared runner (loses fail aggregation unless redesigned)
- Renaming public functions in the same PR as a move
- Introducing Node/pnpm for “tooling” on the core CLI
- Leaving barrels that still contain the old giant function bodies
- Committing `maintainer/temp/`

## Acceptance

- No product file in `lib/` or `modules/` above **400 lines** (soft target 250)
- `tests/smoke.sh` is a **thin runner** (≪ 200 lines); suites live under `tests/smoke/`
- Every former giant has a **named subdir** + thin barrel; call sites still source the barrel path
- `./tests/smoke.sh` green after each slice
- `bash -n` clean on all touched files
- `maintainer/systems/` path maps match the tree

## After ship

- `maintainer/shipped/README.md` — note layout refactor if paths users/docs mention change
- `maintainer/systems/cli.md` + `backup-restore.md` (+ tools/terminal as touched)
- `maintainer/agents/rules.md` — size budget + barrel/subdir convention (already)
- Roadmap: mark slices done; phase **folds** when R-SMOKE + R1–R9 are done or deferred

Umbrella: [`redesign.md`](./redesign.md). Focus: [`focus.md`](./focus.md).
