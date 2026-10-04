# Phase 05 — Space preflight + reversible schema

**Goal:** Refuse to start a backup that will almost certainly fail on disk; archive carries a restore contract.

## Space

Before heavy rsync/pack:

1. Estimate staged size (from plan)
2. Check free space on `--stage-dir` filesystem
3. Check free space on `-o/--output` filesystem (incl. `/mnt/c` when that is the dest)
4. Fail early with clear numbers (human + `--json`)

Same idea later for restore target.

## Schema (restore contract)

Archive includes versioned:

| Artifact | Role |
|----------|------|
| `schema.json` | Version, tool version, host hints (distro family), feature flags |
| `decisions.tsv` (or `.jsonl`) | path, class, action, reason |
| Existing | package manifests, checksums, metadata |

Restore on another machine:

1. Read schema / compatibility
2. Decrypt secrets if needed
3. Restore files idempotently
4. Reinstall packages from manifests
5. Report gaps honestly (no silent invent)

## Slices

- [ ] **05.1** Platform free-space helper (`lib/core/platform/fs_space.sh`)
- [ ] **05.2** Backup preflight gate
- [ ] **05.3** Write `schema.json` + decisions during stage
- [ ] **05.4** `verify` checks schema presence/version
- [ ] **05.5** Document schema fields in `docs/` (phase 06)
- [ ] **05.6** Smoke: tiny backup contains schema + decisions

## Acceptance

- Intentionally tiny `--stage-dir` filesystem → abort before rsync with readable error
- Untarring archive shows `schema.json` + decisions
- Schema version field is stable and bumped intentionally

## After ship

`systems/backup-restore.md` + `shipped/`.
