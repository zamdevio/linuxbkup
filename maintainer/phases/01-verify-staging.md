# Phase 01 — Verify staging

**Goal:** `linuxbkup verify` accepts a finished `*.tar.zst` **or** a staging directory left after a failed/partial pack.

**Non-goals:** Repairing broken archives; restore.

## Why

Pack can fail after staging + INDEX/checksums. Staging is kept on failure today; verify should still prove checksums without re-packing.

## Slices

- [x] **01.1** Detect input kind: file archive vs directory staging root
- [x] **01.2** Staging path: read `checksums.sha256` (+ metadata) in place; report pass/fail
- [x] **01.3** Archive path: extract to temp (or stream) and check as today
- [x] **01.4** Clear errors if neither valid staging nor archive
- [x] **01.5** Smoke: verify against a tiny fixture staging dir

## Acceptance

- `linuxbkup verify /path/to/stage-dir` works when checksums exist
- `linuxbkup verify /path/to/backup.tar.zst` unchanged behavior
- Help lists both forms with generic paths

## After ship

Update `shipped/` + `systems/backup-restore.md`.
