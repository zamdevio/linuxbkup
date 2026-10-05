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

- [x] **04.1** Reclaim list from classifier skip set (`lib/backup/reclaim.sh`)
- [x] **04.2** `--reclaim` / `--reclaim-all` + ask screen (also under `--ask`)
- [x] **04.3** Secret set assembly + `--mark-secret`
- [x] **04.4** `age` encrypt into `secrets.tar.age`; wipe plaintext; `metadata/secrets.env`
- [x] **04.5** Restore decrypt path (`backup_secrets_decrypt_stage` + `restore` wiring)
- [x] **04.6** Smoke: reclaim candidates + age encrypt (expect + `LINUXBKUP_SECRETS_PASS`)

**Encrypt layout:** ephemeral `age-keygen` recipient → `secrets.tar.age`; identity wrapped with `openssl enc -aes-256-cbc -pbkdf2` → `secrets.agekey.enc`. Passphrase via `LINUXBKUP_SECRETS_PASS` / `LINUXBKUP_SECRETS_PASS_FILE` or TTY prompt. `--yes` never leaves secrets plaintext unless `--secrets-plain` / `--no-secrets`.

## Acceptance

- Reclaimed `target/` appears in plan/archive when requested
- Secrets are ciphertext in the archive; plaintext not left in staging after pack
- Missing passphrase on `--yes` without configured secret source → clear error

## After ship

`shipped/` + `systems/backup-restore.md` (+ `systems/secrets.md` if useful).
