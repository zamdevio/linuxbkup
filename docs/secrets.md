# Secrets

Secrets are a **subset** of the backup — not a full home dump of every credential store by default.

## What gets treated as secret

Built-in classification marks common secret paths (SSH keys under `.ssh`, certain credential files, etc.). You can force more:

```bash
./linuxbkup -y --mark-secret '/home/user/.config/some-vault' backup
```

Repeat `--mark-secret` as needed.

## Modes

| Mode | Flag / env | Effect |
|------|------------|--------|
| Encrypt (default when `age` present) | — | Secret paths → `secrets.tar.age` + key material |
| Exclude | `--no-secrets` | Secret paths dropped from the backup |
| Plain | `--secrets-plain` | Secrets included **unencrypted** (explicit opt-in) |

## Passphrase

Encryption needs a passphrase. **Never pass it on argv.**

```bash
export LINUXBKUP_SECRETS_PASS='…'          # or
export LINUXBKUP_SECRETS_PASS_FILE=/path/to/passfile
./linuxbkup -y backup
```

Interactive TTY: you can be prompted (preferred for one-off runs).

### `--yes` rules (strict on purpose)

Under `-y` / non-TTY, backup **refuses to run** unless you have:

1. `LINUXBKUP_SECRETS_PASS` or `_PASS_FILE` (encrypt mode), **or**
2. `--no-secrets`, **or**
3. `--secrets-plain`

`--yes` never silently skips encryption of secret paths.

## Restore

```bash
export LINUXBKUP_SECRETS_PASS='…'
./linuxbkup -k -f restore ~/Backups/linuxbkup/host.tar.zst
```

- Decrypt step runs only when `secrets.tar.age` exists in the archive/stage
- No encrypted secrets → restore continues (logs that there was nothing to decrypt)
- Wrong passphrase → decrypt fails → restore stops before applying files

## What we do not do

- No password manager integration
- No cloud KMS
- No automatic “encrypt everything” — only classified/marked secret paths

If you need whole-home encryption, wrap the archive yourself (`age`, LUKS, etc.) after backup.

Next: [Schema](./schema.md) · [Troubleshooting](./troubleshooting.md)
