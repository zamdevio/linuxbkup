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
3. For redesign work: [`maintainer/phases/redesign.md`](maintainer/phases/redesign.md) + the phase doc Focus names (`00`–`07`).
4. Map reality via [`maintainer/systems/`](maintainer/systems/) and [`maintainer/shipped/`](maintainer/shipped/).
5. Architecture / git gates: [`maintainer/agents/`](maintainer/agents/).
6. Large-file budget + subdir split + smoke suite split: [`maintainer/phases/refactor.md`](maintainer/phases/refactor.md) (soft ≤250 / hard 400; parallel track).
7. Restore UX plan (interrupt parity + picker v2): [`maintainer/phases/11-restore-ux.md`](maintainer/phases/11-restore-ux.md).

`maintainer/temp/` is scratch (gitignored).

## Layout

| Path | Role |
|------|------|
| `linuxbkup` | CLI entry (bin) |
| `lib/core/` | Shared plumbing (common, safety, context, help) |
| `lib/core/terminal/` | style (logging/UI), OSC 8 links, control seqs |
| `lib/core/platform/` | Host detect, dest paths, Windows mount helpers, fs space |
| `lib/cmd/` | One script per CLI command |
| `lib/env/` | Distro, users, capability probes |
| `lib/fs/` | Size / `du` scans |
| `lib/classify/` | Classification (reads constraints) |
| `lib/constraints/` | Built-in path lists + `--full`/`--top` policy |
| `lib/backup/` | Staging + home copy |
| `lib/archive/` | tar.zst pack + checksums |
| `lib/tools/` | Tool checks + install How-To |
| `guides/tools/` | Per-tool `.guide` install snippets |
| `modules/` | Package-manager / subsystem modules (phased) |
| `tests/` | Smoke / regression scripts |
| `docs/` | End-user docs (VitePress content; site in phase 07) |
| `apps/docs/` | **planned** — VitePress → https://linuxbkup.pages.dev |
| `maintainer/` | Control plane (phases, systems, agents, shipped, temp) |

## Rules

1. Bash-first; no Node/Python runtime required for the **core CLI**. Docs site (`apps/docs`) may use Node — CLI must not depend on it.
2. `maintainer/*` is control plane — not product code.
3. `maintainer/temp` is scratch; never commit its contents.
4. Active focus: `maintainer/phases/focus.md` (max 3).
5. Read `maintainer/agents/architecture.md` and `maintainer/agents/git.md`.
6. Phase by phase — implement only what Focus opens; fold into `shipped/` + `systems/` when done.
7. **Do not commit or push unless the user explicitly asks.**
8. Examples/placeholders: generic only (`/home/user`, `~/Backups/linuxbkup/…`).

## Commands

```bash
./linuxbkup --help
./linuxbkup inspect
./tests/smoke.sh

# Optional: put on PATH
ln -sf "$PWD/linuxbkup" ~/.local/bin/linuxbkup
```
