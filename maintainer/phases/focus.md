# Focus

**Rule:** Focus now = **max 3**. Everything else stays queued until a Focus slot frees.

**Standing (not a Focus slot):** [`10-pm-tools-research.md`](./10-pm-tools-research.md) stays **open** — use it as a guide anytime; do not fold until research is done.

**Parallel (not a Focus slot):** [`refactor.md`](./refactor.md) stays **open** — layout splits only. **R-SMOKE** still open. **R1 done**.

**Fold rule:** shipped phases are deleted; outcomes live in [`../shipped/`](../shipped/) + [`../systems/`](../systems/). Open phase docs keep **remaining slices only**.

---
## Focus now

| Priority | Vertical | Notes |
|----------|----------|-------|
| 1 | Restore soak | **iPhone/iSH only for now** — Samsung/Termux later. Agent pack: `maintainer/temp/soak-agent-pack.md`; verify-after-pull prompt is chat-only. After iSH report: fold into shipped/systems |
| 2 | PM research | **Next after soak reports** — standing doc [`10-pm-tools-research.md`](./10-pm-tools-research.md); pull implementation slices into Focus when ready |
| 3 | — | (slot free) |

**Shipped:** docs content (06) + VitePress site (07) → **https://linuxbkup.pages.dev**. Outcomes in [`../shipped/`](../shipped/) + [`../systems/docs-site.md`](../systems/docs-site.md). Schema field docs (05.5) in `docs/schema.md`.

**Dropped:** `/overview` site page — not wanted.

**Soak flow:** **iPhone (iSH) first** — Samsung/Termux not available yet. User runs the phone agent with the pack → paste report back here → fold results → then PM research becomes the implementation Focus (capture/reinstall modules pull from phase 10).

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
| — | Capture modules (mise/pip freeze) | Pull from phase 10 when soak/PM Focus opens |

**Just folded:** Phases 00–04, 05 docs leftover, 06, 07, 08, 09, 11, 12, **13**.

**Locked:** Fail-fast doctrine (09 shipped). Standing PM/tools research in [`10-pm-tools-research.md`](./10-pm-tools-research.md). Regenerable reinstall doctrine: source PM recipe; `-y` = all; `--skip-reinstall` = none. Layout budget in [`refactor.md`](./refactor.md). **Host is untrusted** — use compat wrappers (`lib/core/compat/compat.sh`), never raw GNU flags in `lib/cmd/`.

Umbrella: [`redesign.md`](./redesign.md).
