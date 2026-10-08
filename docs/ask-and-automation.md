# Ask, yes, and automation

How linuxbkup behaves when a human is (or is not) at the keyboard.

## Precedence

```text
--ask  >  --yes  >  non-TTY defaults  >  interactive prompts
```

- `--ask` with `--yes`: ask wins; `--yes` is ignored (logged once)
- Neither flag, non-TTY stdin: treated as `--yes` for include/skip decisions
- Neither flag, interactive TTY: prompts appear where the product allows them

## Interactive (`--ask` or TTY)

| Surface | Behavior |
|---------|----------|
| Unexpected / large paths | Ask during backup classification |
| Overwrite on restore | Per-tree confirm (or `-f` to skip prompts) |
| Reinstall picker | Numbered list: exclude / include / PM filter / grep / fzf / undo |
| Interrupt menu | Written to `/dev/tty` (survives fish/job-control) |

Requires a real TTY for prompts. `--ask` in a pipe/non-TTY will not magically become interactive.

## Non-interactive / CI (`-y`)

```bash
export LINUXBKUP_SECRETS_PASS='…'   # required if secrets stay enabled
linuxbkup -y backup
linuxbkup -y -f restore ~/Backups/linuxbkup/host.tar.zst
linuxbkup -y deps install
```

Rules that stay strict under `-y`:

1. Restore overwrite still needs **`-f`**
2. Secrets encrypt mode still needs a passphrase (env/file) or explicit `--no-secrets` / `--secrets-plain`
3. Destructive reclaim (`-R`) is still explicit
4. `deps` bootstrap may run without an extra prompt when 2+ tools are missing

## Machine-readable plan

```bash
linuxbkup plan --json
```

JSON envelope for scripting (include/skip counts and related plan data). Default plan path sets internal “quick” mode so JSON is not slowed by per-path `du`.

## Tips replay

With flags set, the CLI prints copy-pasteable `linuxbkup … plan|backup` lines that include your current include/exclude/secrets/user/`-y` state — useful after an interactive session.

## Automation checklist

- Secrets: passphrase from secret store → `LINUXBKUP_SECRETS_PASS` or `_PASS_FILE`
- Restore: pass `-f` only on machines/images you intend to overwrite
- Dest: `-o` to a stable path; copy offsite in the same job if you automate further
- Logs: capture stdout/stderr; `-d` for failures
- Exit codes: non-zero on fatal errors — wire into your scheduler

Next: [CLI](./cli.md) · [Secrets](./secrets.md)
