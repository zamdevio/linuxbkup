# AGENT.md — wslbkup

Coding agents: start here.

## What this repo is

`wslbkup` — a Bash-first WSL backup/restore CLI. Orchestrates mature Unix tools (`du`, `rsync`, `tar`, `zstd`, `age`, package managers). Does **not** dump the whole VHDX or `/usr`.

Scaffolded via `@zamdevio/scaffolder` (`cli` preset), then **pivoted to Bash** (scaffolder has no Bash layout). Keep the maintainer control plane; product code is shell.

## Layout

| Path | Role |
|------|------|
| `wslbkup` | CLI entry (bin) |
| `lib/core/` | Shared plumbing (common, safety, context) |
| `lib/core/terminal/` | style (logging/UI), OSC 8 links, control seqs |
| `lib/cmd/` | One script per CLI command |
| `lib/env/` | Distro, users, capability probes |
| `lib/fs/` | Size / `du` scans |
| `lib/windows/` | Windows path / Downloads defaults |
| `lib/classify/` | Classification (reads constraints) |
| `lib/constraints/` | Built-in path lists + `--full`/`--top` policy |
| `lib/tools/` | Tool checks + install How-To |
| `guides/tools/` | Per-tool `.guide` install snippets |
| `modules/` | Package-manager / subsystem modules (phased) |
| `tests/` | Smoke / regression scripts |
| `docs/` | End-user docs |
| `maintainer/` | Control plane (phases, systems, agents, shipped, temp) |
| `maintainer/temp/` | Scratch — **gitignored** |

## Rules

1. Bash-first; no Node/Python runtime required for the core CLI.
2. `maintainer/*` is control plane — not product code.
3. `maintainer/temp` is scratch; never commit its contents.
4. Active focus: `maintainer/phases/focus.md` (max 3).
5. Read `maintainer/agents/architecture.md` and `maintainer/agents/git.md`.
6. Phase by phase — do not jump to Near-full restore in one shot.
7. **Do not commit or push unless the user explicitly asks.**

## Commands

```bash
./wslbkup --help
./wslbkup inspect
./tests/smoke.sh

# Optional: put on PATH
ln -sf "$PWD/wslbkup" ~/.local/bin/wslbkup
```
