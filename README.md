# wslbkup

Safe, reconstructable, **Bash-first** backup and restore for WSL Linux distributions.

> Back up what cannot be reliably regenerated. Record what can.

## Status

Early development. Phase 0 skeleton is in place (`inspect` / `backup` / `restore` / `verify` / `list` dispatch + safety rails). Real scan/backup/restore land in later phases.

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
wslbkup          CLI entry
lib/core/        common, logging, safety
lib/cmd/         inspect, backup, restore, verify, list
modules/         apt, python, node, … (phased)
rules/           classification patterns
tests/           smoke tests
docs/            end-user docs
maintainer/      agent control plane
```

See [`AGENT.md`](./AGENT.md) for contributor/agent entry.
