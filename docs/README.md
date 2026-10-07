# Docs — linuxbkup

End-user documentation for the Linux backup/restore CLI (desktop, VPS, WSL; Alpine/iSH/Termux portability in progress).

Keep this free of sprint language and `maintainer/` links.

## Available

- [`cli.md`](./cli.md) — commands, restore/reinstalls, deps, filters, signals, known gaps

## Planned topics (phase 06+)

- Install / PATH
- `inspect` → `backup` → `restore` workflow
- Default archive location (`~/Backups/linuxbkup/` or Windows Downloads when mounted)
- Secrets passphrase (`age`) and `--yes` rules
- Per-ecosystem regenerables (venv, node_modules, …)
- Supported hosts matrix (GNU vs BusyBox) once phase 13 lands
- Schema / archive layout
