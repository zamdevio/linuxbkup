# wslbkup

Safe, reconstructable, **Bash-first** backup and restore for WSL Linux distributions.

> Back up what cannot be reliably regenerated. Record what can.

## Status

Early development. Phase 1 `inspect` is live. Backup/restore land in later phases.

## Quick start

```bash
cd ~/Tools/wslbkup
./wslbkup --help
./wslbkup inspect          # stub until Phase 1
./tests/smoke.sh
```

Optional PATH install:

```bash
ln -sf "$PWD/wslbkup" ~/.local/bin/wslbkup
```

## Defaults (locked)

- Archive default: `/mnt/c/Users/<WinUser>/Downloads/wslbkup/<distro>-<timestamp>.tar.zst`
- Secrets: passphrase via `age` (subset); `--yes` does not silently skip encryption
- Overwrite on restore requires `--force-overwrite` (not implied by `--yes`)

## Layout

```text
wslbkup             CLI entry
lib/core/           common, safety, context
lib/core/terminal/  style, OSC 8 links, control
lib/cmd/            inspect, backup, restore, verify, list, deps
lib/constraints/    built-in path lists + list policy
lib/tools/          checks + catalog + install helpers
guides/tools/       install How-To per tool
lib/env/ fs/ windows/ classify/
modules/            apt, python, node, … (phased)
tests/              smoke tests
docs/               end-user docs
maintainer/         agent control plane
```

Useful flags: `--include` / `--exclude` (regex), `--no-defaults`, `-F/--full`, `-T/--top <n>`, `--no-color`, `--no-links`.

```bash
wslbkup deps                 # status
wslbkup deps install         # install missing core tools
wslbkup -y deps install age  # one optional tool
```

See [`AGENT.md`](./AGENT.md) for contributor/agent entry.
