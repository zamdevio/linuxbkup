# AGENT.md — linuxbkup

Coding agents: start here.

## What this repo is

Bash-first **Linux** backup/restore CLI. Orchestrates mature Unix tools (`du`, `rsync`, `tar`, `zstd`, `age`, package managers). Does **not** dump whole disks or `/usr`.

**Binary:** `./linuxbkup`  
**Identity:** `linuxbkup` — see [`maintainer/phases/redesign.md`](maintainer/phases/redesign.md). Env prefix: `LINUXBKUP_*` only. WSL is one supported environment, not the brand.

Scaffolded via `@zamdevio/scaffolder` (`cli` preset), then **pivoted to Bash**. Keep the maintainer control plane; product code is shell.

## Start of every session

1. Read this file.
2. Read [`maintainer/phases/focus.md`](maintainer/phases/focus.md) (max 3 Focus items).
3. Redesign umbrella: [`maintainer/phases/redesign.md`](maintainer/phases/redesign.md). Open phase docs only — listed in [`roadmap.md`](maintainer/phases/roadmap.md) (shipped phase docs are **deleted**; outcomes in `shipped/` + `systems/`).
4. Map reality via [`maintainer/systems/`](maintainer/systems/) and [`maintainer/shipped/`](maintainer/shipped/).
5. Architecture / git gates: [`maintainer/agents/`](maintainer/agents/).
6. Large-file budget + smoke split: [`maintainer/phases/refactor.md`](maintainer/phases/refactor.md) (soft ≤250 / hard 400; parallel).
7. **Next product focus:** restore soak (iSH/Termux/Kali checklist `maintainer/temp/13-soak-checklist.md`) then docs site phases [06](maintainer/phases/06-docs-content.md)–[07](maintainer/phases/07-vitepress.md). Phase 13 platform compat is **shipped** (compat layer `lib/core/compat/`).

`maintainer/temp/` is scratch (gitignored).

## Layout

| Path | Role |
|------|------|
| `linuxbkup` | CLI entry (bin) |
| `lib/core/` | common, safety, interrupt, context, help |
| `lib/core/terminal/` | style (logging/UI), OSC 8 links, control seqs |
| `lib/core/platform/` | Host detect, dest paths, Windows mount helpers, fs space |
| `lib/cmd/` | One script per CLI command |
| `lib/env/` | Distro, users, capability probes |
| `lib/fs/` | Size / `du` scans |
| `lib/classify/` | Classification (reads constraints) |
| `lib/constraints/` | Built-in path lists + `--full`/`--top` policy |
| `lib/backup/` | Staging + home copy + `reinstall/*.sh` |
| `lib/archive/` | tar.zst pack + checksums |
| `lib/tools/` | Tool checks + install How-To + lean compat probes |
| `guides/tools/` | Per-tool `.guide` install snippets |
| `modules/` | Package-manager / subsystem modules |
| `tests/` | Smoke — thin runner `tests/smoke.sh` |
| `docs/` | End-user docs |
| `maintainer/` | Control plane (phases, systems, agents, shipped, temp) |

## Rules

1. Bash-first; no Node/Python runtime required for the **core CLI**. Docs site may use Node — CLI must not depend on it.
2. `maintainer/*` is control plane — not product code.
3. `maintainer/temp` is scratch; never commit its contents.
4. Active focus: `maintainer/phases/focus.md` (max 3).
5. Read `maintainer/agents/architecture.md` and `maintainer/agents/git.md`.
6. Phase by phase — implement only what Focus opens; fold into `shipped/` + `systems/` then **delete** the phase doc.
7. **Do not commit or push unless the user explicitly asks.**
8. Examples/placeholders: generic only (`/home/user`, `~/Backups/linuxbkup/…`).
9. Do not assume GNU flags; prefer wrappers (phase 13) when touching tar/rsync/zstd/sha256sum.

## Commands

```bash
./linuxbkup --help
./linuxbkup inspect
./tests/smoke.sh

# Optional: put on PATH
ln -sf "$PWD/linuxbkup" ~/.local/bin/linuxbkup
```
