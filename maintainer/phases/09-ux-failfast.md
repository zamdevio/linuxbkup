# Phase 09 — UX fail-fast + honest progress

**Goal:** Never punish the user with a long wait that dies on a precondition we could have checked in seconds. Estimates and stage totals must tell the same story.

## Doctrine (locked)

| Rule | Detail |
|------|--------|
| Fail fast | Preconditions that need env/flags/TTY input are resolved **before** heavy work (rsync, checksum, pack). |
| One story for size | “Estimated include” and “Stage used” use the same filter stack and byte-accurate `du`; human labels are derived from bytes, not the reverse. |
| No surprise gates | Secrets passphrase / `--no-secrets` / `--secrets-plain` decided before copy starts. |
| Progress honesty | Progress bar path list matches what will actually stage; soft-skips explained; abort leaves staging + next command. |
| Tip replay | Tips never suggest flags that disagree with the run that just failed. |
| Coming work | Same doctrine for space preflight (05), multi-PM capture, restore — gate early, work late. |

## Anti-patterns (seen in the wild)

1. Copy 100 paths for minutes → then fatal: missing `LINUXBKUP_SECRETS_PASS`
2. Estimate ~6.0GB (parsed rounded `du -sh` strings) → stage 6.9GB (byte `du -sb`)
3. Tip line with typos / stale excludes after a failed run

## Slices

- [x] **09.1** Secrets mode resolved before staging/copy (prompt or fatal under `--yes`)
- [x] **09.2** Byte-accurate filtered estimates (no sum-of-rounded-human)
- [x] **09.3** After copy: show estimate vs stage delta when > threshold (e.g. 5% or 50MiB)
- [x] **09.4** Preflight banner: secrets mode + gitignore + max-size + profile in one glance
- [x] **09.5** Structured step labels (`ui_step`) — preflight → detect → capture → stage → seal → pack → summary
- [x] **09.6** Smoke: `--yes` backup without pass fails before any rsync into stage

## Acceptance

- `linuxbkup -y backup` with secrets and no pass → fatal **before** “Copying into staging”
- Estimate and stage used within ~5% on a Python-heavy tree when filters apply (`__pycache__`, `venv`, …)
- Phase doc referenced from `focus.md` / `redesign.md`

## After ship

`systems/terminal.md` + `systems/backup-restore.md` + `shipped/`.
