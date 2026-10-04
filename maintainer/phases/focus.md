# Focus

**Rule:** Focus now = **max 3**. Everything else stays queued until a Focus slot frees.

---

## Focus now

| Priority | Vertical | Notes |
|----------|----------|-------|
| 1 | Phase 0 skeleton | Done this round: dispatch, logging, safety, stubs |
| 2 | Phase 1 inspect | Distro/users/capabilities, du report, Downloads path preview |
| 3 | Maintainer docs | Architecture/systems aligned with Bash pivot |

## Queued — do not start

| # | Item | Why parked |
|---|------|------------|
| 1 | Phase 2 backup core | Needs inspect first |
| 2 | Phase 3 secrets/age | Needs backup staging |
| 3 | Phase 4 restore | Needs archive format |
| 4 | Phase 5 language modules | After restore foundation |
| 5 | Phase 6 systemd + /etc | After language modules |
| 6 | Phase 7 Docker + polish | Last |

## Next task

1. Implement Phase 1 `inspect` for real (not stub).
2. Keep Focus slots ≤ 3; promote Phase 2 only after inspect is usable.
