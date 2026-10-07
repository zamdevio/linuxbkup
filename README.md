# linuxbkup

Safe, reconstructable, **Bash-first** backup and restore for Linux (desktop, VPS, WSL, Alpine/iSH, Termux — portability in progress).

> Back up what cannot be reliably regenerated. Record what can.

## Status

**Live commands:** `inspect`, `plan`, `backup`, `verify`, `restore` (files + Node reinstalls), `list`, `deps`.

**Recent (phases 11–12):** reinstall picker v2, interrupt parity + soft-quit, workspace-root installs, nm auto-skip, prefix-tolerant archive extract.

**Next (phase 13):** platform/tool compat layer, Ctrl+Z restore/backup, stage-path printing, atomic archives — see [`maintainer/phases/13-platform-compat.md`](maintainer/phases/13-platform-compat.md).

**Docs site (06–07):** planned — `docs/` is the content source until VitePress ships.

## Quick start

```bash
cd /path/to/linuxbkup
./linuxbkup --help
./linuxbkup inspect
./tests/smoke.sh
```

Optional PATH install:

```bash
ln -sf "$PWD/linuxbkup" ~/.local/bin/linuxbkup
```

```bash
./linuxbkup -y backup
./linuxbkup -k -f restore ~/Backups/linuxbkup/<archive>.tar.zst
./linuxbkup deps
```

## Defaults (locked)

- Archive default: `~/Backups/linuxbkup/<distro>-<timestamp>.tar.zst` (native), or Windows Downloads when a mount is available
- Override with `-o` / `--output`
- Secrets: passphrase via `age` (subset); `--yes` does not silently skip encryption
- Overwrite on restore requires `--force-overwrite` (not implied by `--yes`)
- Env prefix: `LINUXBKUP_*` only. WSL is one environment, not the brand.

## Layout

```text
linuxbkup                 CLI entry
lib/core/                 common, safety, interrupt, context, help
lib/core/terminal/        style, OSC 8 links, control, progress, events
lib/core/platform/        detect, paths, windows mount, fs space
lib/cmd/                  inspect, plan, backup, restore, verify, list, deps
lib/backup/               staging, home copy, restore, reinstall/*.sh
lib/archive/              tar.zst pack, checksums, verify
lib/constraints/          path lists + list policy (-F/-T)
lib/env/ lib/fs/ lib/classify/ lib/tools/
modules/                  apt, node, …
guides/tools/             install How-To per tool
tests/                    thin runner tests/smoke.sh
docs/                     end-user docs (cli.md today)
maintainer/               agent control plane (phases, systems, shipped)
```

## Hosts & tools (honest)

Assumes **Linux-like** hosts with `tar`, `zstd`, `rsync`, `sha256sum` (or close). GNU coreutils is the happy path. BusyBox/iSH/Termux/old distros may lack flags or binaries — **compat layer is phase 13**, not finished. Run `linuxbkup deps` first.

Useful flags: `--include` / `--exclude` (regex), `--no-defaults`, `-F/--full`, `-T/--top <n>`, `--no-color`, `--no-links`, `-k/--keep-stage`, `-a/--ask`, `-y/--yes`.

See [`AGENT.md`](./AGENT.md) for contributor/agent entry and [`docs/cli.md`](./docs/cli.md) for the CLI reference.
