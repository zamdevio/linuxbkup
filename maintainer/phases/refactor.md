# Refactor — layout & large-file split

**Goal:** Keep the Bash product **easy to maintain** by splitting oversized modules into focused subdirectories (`lib/backup/reinstall/*.sh`) — **codebase-wide**, not a one-off on `reinstall.sh`.

**Status:** planned. Pull into a Focus slot when ready (max 3). Pure structure — **no product behavior changes**.

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
| No magic PATH | Subdir files are **not** auto-discovered by the CLI. Only the barrel (or cmd script) sources them. |
| Verify each slice | `bash -n` every touched file + `./tests/smoke.sh` green before the next split. |
| Docs same day | After a landed split: `maintainer/systems/` path map + `shipped/` if user-facing paths change. |

## Target shape (example)

```text
lib/backup/reinstall.sh          # thin barrel (loader only)
lib/backup/reinstall/
  manifest.sh                    # load tsv/json rows, peek from archive/stage
  pm.sh                          # Linux-only resolve, status lines, recipes, corepack
  preflight.sh                   # preflight guide + list policy rendering
  select.sh                      # project picker (TTY / fzf / -y / --ask)
  run.sh                         # run_one + reinstall_apply + summary
```

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

Call sites (`lib/cmd/restore.sh`, `tests/smoke.sh`) keep:

```bash
source "${LINUXBKUP_ROOT}/lib/backup/reinstall.sh"
```

## Inventory (today — wc -l)

Split when a slice is being touched **or** file is already over the soft cap:

| File | Lines | Suggested split |
|------|------:|-----------------|
| `lib/backup/reinstall.sh` | ~610 | `reinstall/{manifest,pm,preflight,select,run}.sh` |
| `lib/backup/home.sh` | ~584 | `backup/home/{rank,rsync,copy}.sh` (paths/excludes stay small) |
| `lib/cmd/backup.sh` | ~350 | keep cmd thin; push helpers into `backup/` modules (watch cap) |
| `lib/core/safety.sh` | ~337 | `core/safety/{confirm,overwrite,signals,rsync}.sh` |
| `lib/cmd/deps.sh` | ~306 | `cmd/deps/{status,install}.sh` or keep cmd + push status to `tools/` |
| `lib/backup/secrets_crypt.sh` | ~306 | `backup/secrets/{mode,age,crypt}.sh` |
| `lib/fs/sizes.sh` | ~298 | `fs/sizes/{parse,du,targets}.sh` |
| `lib/tools/check.sh` | ~287 | `tools/check/{resolve,guides,status}.sh` |
| `lib/constraints/regenerable.sh` | ~287 | `constraints/regenerable/{lists,filters}.sh` |
| `lib/core/help.sh` | ~279 | `core/help/{usage,commands}.sh` |
| `lib/core/interrupt.sh` | ~276 | `core/interrupt/{ops,menu,resolve}.sh` |
| `modules/node.sh` | ~258 | `modules/node/{detect,capture}.sh` |
| `lib/cmd/restore.sh` | ~239 | near budget; split only if it grows |
| `lib/core/common.sh` | ~238 | parse/globals vs helpers if it grows |
| `lib/core/terminal/progress.sh` | ~229 | near budget; leave unless touching |
| `lib/backup/restore_files.sh` | ~204 | leave unless touching |
| `tests/smoke.sh` | ~1077 | **special:** later `tests/smoke/*.sh` + thin runner — not product code |

Already-good directory examples (copy this pattern): `lib/core/terminal/`, `lib/core/platform/`, `lib/classify/`.

## Slices (Focus-sized; max 3 open at a time)

- [ ] **R1. reinstall split** — barrel + `lib/backup/reinstall/*.sh`; smoke sources still `…/reinstall.sh`
- [ ] **R2. backup/home split** — `home/{rank,rsync,copy}.sh`; barrel `lib/backup/home.sh`
- [ ] **R3. safety split** — confirm/overwrite vs signals/rsync; traps still installed once via `linuxbkup_install_traps`
- [ ] **R4. secrets split** — mode resolution vs age encrypt/decrypt
- [ ] **R5. tools/check split** — resolve+list policy vs guides vs install
- [ ] **R6. interrupt split** — op lifecycle vs menu/resolve
- [ ] **R7. help split** — global usage vs per-command help text
- [ ] **R8. sizes/regenerable/node** — remaining soft-cap offenders in priority order
- [ ] **R9. cmd thin-out** — `backup.sh` / `deps.sh` / `restore.sh` orchestration only
- [ ] **R10. smoke modularization** — optional; `tests/smoke/` + `tests/smoke.sh` runner

**Priority when opening Focus:** R1 → R2 → R3 (largest product modules first). R10 last or never if smoke stays green as one file.

## Per-slice checklist

1. Read the file; group functions by responsibility (comments in source help).
2. Create `lib/<area>/<name>/` + move groups; leave **only** `source` lines in the old `*.sh` barrel.
3. `bash -n` barrel + every child.
4. `./tests/smoke.sh` — no new FAILs.
5. `rg "source .*reinstall.sh"` (or the split name) — call sites unchanged unless a slice renames the entry (then update smoke + cmds **in the same commit**).
6. Update `maintainer/systems/<area>.md` path table.
7. Update this phase’s slice checkbox + `roadmap.md` status.

## Anti-patterns (do not)

- Splitting into 20 files of 20 lines each “for cleanliness”
- Auto-`source` every `*.sh` in a directory (order + side effects become magic)
- Renaming public functions in the same PR as a move
- Introducing Node/pnpm for “tooling” on the core CLI
- Leaving barrels that still contain the old giant function bodies
- Committing `maintainer/temp/`

## Acceptance

- No product file in `lib/` or `modules/` above **400 lines** (soft target 250)
- Every former giant has a **named subdir** + thin barrel; call sites still source the barrel path
- `./tests/smoke.sh` green after each Focus batch
- `bash -n` clean on all touched files
- `maintainer/systems/` path maps match the tree

## After ship

- `maintainer/shipped/README.md` — note layout refactor if paths users/docs mention change
- `maintainer/systems/cli.md` + `backup-restore.md` (+ tools/terminal as touched)
- `maintainer/agents/rules.md` — one line: size budget + barrel/subdir convention
- Roadmap: mark R-slices done; this phase **folds** when R1–R9 are done or explicitly deferred

Umbrella: [`redesign.md`](./redesign.md). Focus: [`focus.md`](./focus.md).
