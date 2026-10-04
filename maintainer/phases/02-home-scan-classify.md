# Phase 02 — Full home scan + classify

**Goal:** Replace hardcoded allowlists with a full `$HOME` scan (`~/*` and `~/.*`), classify, and **report unexpected** paths.

**Non-goals:** Dumping `/` or other users’ homes without explicit flags (multi-user later).

## Locked behavior

| Class | Default |
|-------|---------|
| Regenerable (`node_modules`, `target/`, venv, …) | skip (reclaim later) |
| Auto-secret (`.ssh`, `.gnupg`, …) | include → secret pipeline |
| Known include (dot configs, `.local/{bin,share,state}`, …) | include |
| Unexpected / unknown | **report always**; non-TTY or `--yes` → **auto-include**; TTY → ask on backup |
| Large (per profile) | suggest skip/include per profile; see phase 03 |

**`.local`:** never “skip all of `.local`”. Include `bin` / `share` / `state`; strip known regenerable subtrees; other children → unexpected.

**Examples:** never personal machine paths — use `/home/user/.local/custom-dir`.

## Slices

- [x] **02.1** Full scan replaces allowlists as the *only* include source
- [x] **02.2** Shallow/quick scan of `$HOME` top-level + `~/.local/*` (filter stack; du optional via `-v`)
- [x] **02.3** Classifier outputs: path, class, size, suggested action, reason
- [x] **02.4** Unexpected reporter + optional TSV via `--json`
- [x] **02.5** Wire non-TTY / `--yes` auto-include for unexpected
- [x] **02.6** `inspect` / `backup --print-plan` share the same plan
- [x] **02.7** Constraints *rules* in `lib/constraints/rules.sh` (basenames/classes)

## Acceptance

- Custom dir like `/home/user/.local/custom-dir` appears as unexpected and is included under `--yes`
- No host-shaped dirname allowlist as the product default
- `inspect` and `backup --print-plan` agree on classes
- Reported sizes match filter stack when sized (`-v`)

## After ship

`systems/constraints.md` + `systems/inspect.md` + `shipped/`.
