# Focus

**Rule:** Focus now = **max 3**. Everything else stays queued until a Focus slot frees.

**Standing (not a Focus slot):** [`10-pm-tools-research.md`](./10-pm-tools-research.md) stays **open** — use it as a guide anytime; do not fold until research is done.

**Parallel (not a Focus slot):** [`refactor.md`](./refactor.md) stays **open** — layout splits only. **R-SMOKE** still open. **R1 done**.

**Fold rule:** shipped phases are deleted; outcomes live in [`../shipped/`](../shipped/) + [`../systems/`](../systems/). Open phase docs keep **remaining slices only**.

---
## Focus now

| Priority | Vertical | Notes |
|----------|----------|-------|
| 1 | Restore soak | Kali + iSH/Termux after 13 landed — checklist `maintainer/temp/13-soak-checklist.md`; workspace gaps already documented |
| 2 | Phases 06–07 docs site | Content rewrite **now that 13 shipped** — docs describe shipped behavior |
| 3 | — | (slot free until soak/docs land) |

## Parallel — refactor (open)

| Slice | Target |
|-------|--------|
| R-SMOKE | `tests/smoke.sh` → `_lib.sh` + `01`–`07` + thin runner |
| ~~R1~~ | ~~reinstall barrel split~~ **done** |
| R2+ | home / safety / secrets / tools — see [`refactor.md`](./refactor.md) |

## Queued — do not start

| # | Item | Why parked |
|---|------|------------|
| — | Python / Go reinstall slices | Same JSON pattern after Node hardens |
| — | Capture modules (mise/pip freeze) | Pull from phase 10 when Node done |
| — | Schema field docs | Fold into phase 06 (05 code already shipped) |

**Just folded:** Phases 00–04, 08, 09, 11, 12, **13**. Phase 05 = docs-only leftover.

**Locked:** Fail-fast doctrine (09 shipped). Standing PM/tools research in [`10-pm-tools-research.md`](./10-pm-tools-research.md). Regenerable reinstall doctrine: source PM recipe; `-y` = all; `--skip-reinstall` = none. Layout budget in [`refactor.md`](./refactor.md). **Host is untrusted** — use compat wrappers (`lib/core/compat/compat.sh`), never raw GNU flags in `lib/cmd/`.

Umbrella: [`redesign.md`](./redesign.md).
