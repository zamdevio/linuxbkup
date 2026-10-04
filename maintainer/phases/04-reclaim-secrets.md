# Phase 04 — Reclaim regenerables + secrets

**Goal:** Let users pull regenerable skips back into the archive; mark/encrypt secrets with `age`.

**Non-goals:** Full disk encryption; syncing secrets to a cloud KMS.

## Reclaim

Regenerable basenames (`node_modules`, `target`, `.venv`, …) default skip.

- `--reclaim` — interactive pick among skipped regenerables (or ask-step)
- `--reclaim-all` — include all matched regenerables (warn on size)
- Ask flow can offer a reclaim screen when TTY/`--ask`

## Secrets

1. Auto-secret paths (`.ssh`, `.gnupg`, …) always enter secret set when included
2. `--mark-secret <path>` / ask “mark as secret?” after path choices
3. Encrypt secret subset with `age` (passphrase)
4. Restore decrypts when passphrase provided
5. **`--yes` does not silently skip encryption** — fail or require non-interactive secret source (env/file) documented in docs; never drop secrets on the floor quietly

## Slices

- [ ] **04.1** Reclaim list from classifier skip set
- [ ] **04.2** `--reclaim` / `--reclaim-all` + ask screen
- [ ] **04.3** Secret set assembly + `--mark-secret`
- [ ] **04.4** `age` encrypt into archive layout; metadata flags encrypted=true
- [ ] **04.5** Restore decrypt path (may stub until restore phase if Focus says so — prefer encrypt side first)
- [ ] **04.6** Smoke with tiny secret fixture + passphrase file

## Acceptance

- Reclaimed `target/` appears in plan/archive when requested
- Secrets are ciphertext in the archive; plaintext not left in staging after pack
- Missing passphrase on `--yes` without configured secret source → clear error

## After ship

`shipped/` + `systems/backup-restore.md` (+ `systems/secrets.md` if useful).
