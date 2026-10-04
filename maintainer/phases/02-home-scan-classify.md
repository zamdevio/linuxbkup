# Phase 02 — Full home scan + classify

**Goal:** Replace hardcoded allowlists with a full `$HOME` scan (`~/*` and `~/.*`), classify, and **report unexpected** paths.

**Non-goals:** Dumping `/` or other users’ homes without explicit flags (multi-user later).

## Locked behavior

| Class | Default |
|-------|---------|
| Regenerable (`node_modules`, `target/`, venv, …) | skip (reclaim later) |
| Auto-secret (`.ssh`, `.gnupg`, …) | include → secret pipeline |
| Known include (dot configs, `.local/{bin,share,state}`, projects-shaped dirs) | include |
| Unexpected / unknown | **report always**; non-TTY or `--yes` → **auto-include**; TTY/`--ask` → decide |
| Large (per profile) | suggest skip/include per profile; see phase 03 |

**`.local`:** never “skip all of `.local`”. Include `bin` / `share` / `state`; strip known regenerable subtrees.

**Examples:** never personal machine paths — use `/home/user/.local/custom-dir`.

## Note (pre-02)

Host-shaped dirnames (`Projects`, `Workers`, `Tools`, …) were **removed** from shipped allowlists so defaults stay portable. Until this phase lands, users `--include` extra trees; sizes already apply the regenerable/user filter stack.

## Slices

- [ ] **02.1** Full scan replaces allowlists as the *only* include source (portable defaults already cleaned)
- [ ] **02.2** Shallow/quick scan of `$HOME` top-level + important nest (no deep `du` hang; filter stack)
- [ ] **02.3** Classifier outputs: path, class, size, suggested action, reason
- [ ] **02.4** Unexpected reporter: human table + optional `--json` fields
- [ ] **02.5** Wire non-TTY / `--yes` auto-include for unexpected
- [ ] **02.6** Update `inspect` to show the same classification preview
- [ ] **02.7** Constraints become *rules* (basenames, globs, classes) not host-specific paths

## Acceptance

- Custom dir like `/home/user/.local/custom-dir` appears as unexpected and is included under `--yes`
- No host-shaped dirname allowlist as the product default
- `inspect` and `backup --print-plan` agree on classes
- Reported sizes match filter stack (regenerable + `--exclude`)

## After ship

`systems/constraints.md` + `systems/inspect.md` + `shipped/`.
