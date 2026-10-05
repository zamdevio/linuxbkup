# Phase 12 — restore reinstall hardening (post Kali soak)

**Goal:** Make `--reinstall-only` + reinstall batch correct on any Linux host: archive extract, workspace-aware installs, non-interactive PMs, interrupt-proof batch.

**Status:** **landed** (product + smoke + docs) — soak on Kali archive next.

## Why (real run 2026-10-05, 140 Node projects)

| Observed | Cause |
|----------|--------|
| `tar: packages: Not found in archive` | Pack stores `./packages/...`; extract only tried bare `packages` |
| `select.sh:33: 122 18: invalid variable name` | Broken `${!cnt[@]+word}` expansion in picker counts |
| `ERR_PNPM_IGNORED_BUILDS` | pnpm 10 blocks build scripts unless approved |
| `@push/core` / `@nextgen/db` missing | Workspace **sources** not on disk at target home, or nested members listed as separate rows |
| Ctrl+C on `npm ci` | Menu not reliable across PM spawn + workspace/package.json checks |

## Doctrine

| Rule | Detail |
|------|--------|
| Generic paths | No hostnames. Rows are **relative** to target home. Same tsv on any machine. |
| Workspace = same tree | `@push/core` resolves via the **same** `pnpm-workspace.yaml` / `package.json` workspaces as its root. Never a separate global install. |
| Root install | One `pnpm i` at the **workspace root** installs all members/apps under it. Nested workspace members are **not** separate reinstall rows. |
| Sources ≠ regenerables | Workspace member **source** must be captured in backup. Missing source → clear skip, not a late pnpm error. |
| PMs never prompt | Restore regenerates `node_modules` — not a supply-chain audit. pnpm: allow-all-builds (non-interactive). npm: no approval gate. |
| Interrupt-safe | Ctrl+C/Z at **any** reinstall step (manifest read, workspace check, PM spawn) → menu or soft-quit. Partial batch summary. Never corrupt mid-install silently. |
| `-y` / `--skip-reinstall` | Unchanged: all / none. No per-PM overrides. |

## `$HOME` vocabulary

- **Target home** = restore target (`SUDO_USER` / `LINUXBKUP_HOME` / `$HOME`) — e.g. `/home/zamdevio`.
- **Node project** = `package.json` dir under target home (`Workers/push`, `Projects/NextGen`, …).
- **Workspace member** = source package under a workspace root (`packages/core` → `@push/core`), resolved by the root's workspace config — same tree, same `pnpm i`.

## Slice

- [x] **A2** picker counts + single Selected line
- [x] **A1** archive extract prefix (`reinstall_archive_pkg_prefix` + `reinstall_extract_manifest`)
- [x] **A3** pnpm non-interactive allow-all-builds (env + `--config.dangerouslyAllowAllBuilds=true`)
- [x] **B** filter nested workspace members; install at workspace root only; clear skip when sources missing
- [x] **A4** interrupt hardening: `reinstall_interrupt_boundary` before each project; disarm/arm around workspace checks
- [x] **D** progress `[i/N]`, quieter OK logs, accurate restore status on soft-quit
- [x] **D5** smoke: extract prefix, counts, workspace-root-only, allow-builds

## Out of scope

- Dropping `lib/backup/reinstall.sh` barrel (keep — load-order contract)
- Full smoke `$HOME` hang → R-SMOKE
- yarn/bun deep soak after pnpm path is solid
- Capture modules (mise/pip) → phase 10 queue

## Acceptance

- `linuxbkup -a --reinstall-only <archive>` extracts manifest (prefix-tolerant) and reinstalls without picker crash.
- Workspace root with `workspace:*` members: one root install; nested members not listed separately.
- Missing workspace source on a **different** machine: skip with "sources not in home — full restore first".
- pnpm install does not fail on `ERR_PNPM_IGNORED_BUILDS`.
- Ctrl+C during batch → menu (r/s/c/q); q = soft-quit + partial summary; Ctrl+Z suspends.
- Focused reinstall smoke green; `bash -n` clean.

## After ship

- Update `maintainer/systems/backup-restore.md` + `shipped/` + `11-restore-ux.md` pointer.
- Kali soak again on the same archive.

Umbrella: [`redesign.md`](./redesign.md). Focus: [`focus.md`](./focus.md). Prior: [`11-restore-ux.md`](./11-restore-ux.md).
