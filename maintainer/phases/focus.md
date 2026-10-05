# Focus

**Rule:** Focus now = **max 3**. Everything else stays queued until a Focus slot frees.

**Standing (not a Focus slot):** [`10-pm-tools-research.md`](./10-pm-tools-research.md) stays **open** — use it as a guide anytime; do not fold until research is done.

**Parallel (not a Focus slot):** [`refactor.md`](./refactor.md) stays **open** — layout splits only; do not block product Focus on it. **R-SMOKE** still open. **R1 done**.

**Fold rule:** shipped phases are deleted; outcomes live in [`../shipped/`](../shipped/) + [`../systems/`](../systems/). Open phase docs keep **remaining slices only**.

---
## Focus now

| Priority | Vertical | Notes |
|----------|----------|-------|
| 1 | Node reinstalls | PM status + list policy + picker; **Kali soak next** (phases 11–12 shipped) |
| 2 | Phases 06–07 docs site | End-user docs + VitePress |
| 3 | Restore / reinstall | Soak 140-project archive; fix any remaining workspace/PM gaps |

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

**Just folded:** Phases 00–04, 08, 09, 11, 12 (docs deleted; outcomes in shipped/ + systems/). Phase 05 trimmed to docs-only leftover.

**Locked:** Fail-fast doctrine (09 shipped). Standing PM/tools research in [`10-pm-tools-research.md`](./10-pm-tools-research.md). Regenerable reinstall doctrine: source PM recipe; `-y` = all; `--skip-reinstall` = none. Layout budget in [`refactor.md`](./refactor.md).

Umbrella: [`redesign.md`](./redesign.md).
