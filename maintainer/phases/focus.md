# Focus

**Rule:** Focus now = **max 3**. Everything else stays queued until a Focus slot frees.

**Standing (not a Focus slot):** [`10-pm-tools-research.md`](./10-pm-tools-research.md) stays **open** — use it as a guide anytime; do not fold until research is done.

**Parallel (not a Focus slot):** [`refactor.md`](./refactor.md) stays **open** — layout splits only; do not block product Focus on it. **R-SMOKE** still open (`tests/smoke/*.sh`). **R1 done** (reinstall barrel split).

---
## Focus now

| Priority | Vertical | Notes |
|----------|----------|-------|
| 1 | Node reinstalls | PM status + list policy + fzf pick; **Kali soak next** |
| 2 | Phases 06–07 docs site | End-user docs + VitePress |
| 3 | Restore UX | **Phase 11 landed** — soft-quit batch + picker v2 + failure re-run; soak on real 100+ project restore |

## Parallel — refactor (open)
| Slice | Target |
|-------|--------|
| R-SMOKE | `tests/smoke.sh` → `_lib.sh` + `01`–`07` + thin runner |
| ~~R1~~ | ~~`lib/backup/reinstall.sh` → `lib/backup/reinstall/*.sh`~~ **done** |
| R2+ | home / safety / secrets / tools — see [`refactor.md`](./refactor.md) |

## Queued — do not start

| # | Item | Why parked |
|---|------|------------|
| — | Python / Go reinstall slices | Same JSON pattern after Node hardens |
| — | Capture modules (mise/pip freeze) | Pull from phase 10 when Node done |

**Just folded:** Phase 11 restore UX (soft-quit interrupt parity + picker v2 + R1 reinstall split).

**Locked:** Fail-fast UX in [`09-ux-failfast.md`](./09-ux-failfast.md). Standing PM/tools research in [`10-pm-tools-research.md`](./10-pm-tools-research.md). Regenerable reinstall doctrine: source PM recipe; `-y` = all; `--skip-reinstall` = none; no `--node`/`--python` overrides. Layout budget + barrel/subdir + smoke suite split in [`refactor.md`](./refactor.md).

Umbrella: [`redesign.md`](./redesign.md).
