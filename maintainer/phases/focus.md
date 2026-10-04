# Focus

**Rule:** Focus now = **max 3**. Everything else stays queued until a Focus slot frees.

---

## Focus now

| Priority | Vertical | Notes |
|----------|----------|-------|
| 1 | Phase 2 backup core | APT manifests + allowlisted home/config + tar.zst → Downloads |
| 2 | Deps / inspect polish | Live — only touch if something breaks |
| 3 | — | slot free |

## Queued — do not start

| # | Item | Why parked |
|---|------|------------|
| 1 | Phase 3 secrets/age | Needs backup staging |
| 2 | Phase 4 restore | Needs archive format |
| 3 | Phase 5 language modules | After restore foundation |
| 4 | Phase 6 systemd + /etc | After language modules |
| 5 | Phase 7 Docker + polish | Last |

## Next task

1. Phase 2: real `backup` — staging dir, APT manual packages, home/config allowlist, large-item triage, `tar`+`zstd` to Windows Downloads, checksums.
2. Keep `inspect` / `deps` stable while backup lands.

Full tracker: [`roadmap.md`](./roadmap.md).
