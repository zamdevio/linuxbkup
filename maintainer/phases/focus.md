# Focus

**Rule:** Focus now = **max 3**. Everything else stays queued until a Focus slot frees.

---

## Focus now

| Priority | Vertical | Notes |
|----------|----------|-------|
| 1 | Phase 3 secrets/age | Encrypt `secrets/` with passphrase; `--yes` rules |
| 2 | Phase 2 backup | Live v1 — harden / triage UX as needed |
| 3 | — | slot free |

## Queued — do not start

| # | Item | Why parked |
|---|------|------------|
| 1 | Phase 4 restore | Needs archive format (have it) + secrets story |
| 2 | Phase 5 language modules | After restore foundation |
| 3 | Phase 6 systemd + `/etc` | After language modules |
| 4 | Phase 7 Docker + polish | Last |

## Next task

1. Phase 3: `age` encrypt secrets subset; interactive passphrase / skip / exclude; `--yes` via env/flags.
2. Smoke a real (non-dry-run) small backup when convenient.

Full tracker: [`roadmap.md`](./roadmap.md).
