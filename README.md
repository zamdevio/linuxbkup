# linuxbkup

Safe, reconstructable, **Bash-first** backup and restore for Linux (desktop, VPS, and WSL).

> Back up what cannot be reliably regenerated. Record what can.

## Status

Early development. `inspect`, `backup` (v1), `verify`, and `deps` are live. Redesign track under `maintainer/phases/`.

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

## Defaults (locked)

- Archive default: `~/Backups/linuxbkup/<distro>-<timestamp>.tar.zst` (native), or Windows Downloads when a mount is available
- Override with `-o` / `--output`
- Secrets: passphrase via `age` (subset); `--yes` does not silently skip encryption
- Overwrite on restore requires `--force-overwrite` (not implied by `--yes`)

## Layout

```text
linuxbkup           CLI entry
lib/core/           common, safety, context, help
lib/core/terminal/  style, OSC 8 links, control
lib/core/platform/  detect, paths, windows mount, fs space
lib/cmd/            inspect, backup, restore, verify, list, deps
lib/constraints/    built-in path lists + list policy
lib/tools/          checks + catalog + install helpers
guides/tools/       install How-To per tool
lib/env/ fs/ classify/
modules/            apt, … (phased)
tests/              smoke tests
docs/               end-user docs
maintainer/         agent control plane
```

Useful flags: `--include` / `--exclude` (regex), `--no-defaults`, `-F/--full`, `-T/--top <n>`, `--no-color`, `--no-links`.

```bash
linuxbkup deps                 # status
linuxbkup deps install         # install missing core tools
linuxbkup -y deps install age  # one optional tool
```

See [`AGENT.md`](./AGENT.md) for contributor/agent entry.
