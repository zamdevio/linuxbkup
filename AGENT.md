# AGENT.md — linuxbkup (tree still named wslbkup until phase 00)

Coding agents: start here.

## What this repo is

Bash-first **Linux** backup/restore CLI. Orchestrates mature Unix tools (`du`, `rsync`, `tar`, `zstd`, `age`, package managers). Does **not** dump whole disks or `/usr`.

**Today’s binary:** `./wslbkup` (pre-rename).  
**Target identity:** `linuxbkup` — see [`maintainer/phases/redesign.md`](maintainer/phases/redesign.md). Clean rename in phase 00 — **no** legacy aliases/env.

Scaffolded via `@zamdevio/scaffolder` (`cli` preset), then **pivoted to Bash**. Keep the maintainer control plane; product code is shell.

## Start of every session

1. Read this file.
2. Read [`maintainer/phases/focus.md`](maintainer/phases/focus.md) (max 3 Focus items).
3. For redesign work: [`maintainer/phases/redesign.md`](maintainer/phases/redesign.md) + the phase doc Focus names (`00`–`07`).
4. Map reality via [`maintainer/systems/`](maintainer/systems/) and [`maintainer/shipped/`](maintainer/shipped/).
5. Architecture / git gates: [`maintainer/agents/`](maintainer/agents/).

`maintainer/temp/` is scratch (gitignored).

## Layout

| Path | Role |
|------|------|
| `wslbkup` | CLI entry (bin) — rename → `linuxbkup` in phase 00 |
| `lib/core/` | Shared plumbing (common, safety, context, help) |
| `lib/core/terminal/` | style (logging/UI), OSC 8 links, control seqs |
| `lib/core/platform/` | **planned** (phase 00) — detect, paths, windows mount, space |
| `lib/cmd/` | One script per CLI command |
| `lib/env/` | Distro, users, capability probes |
| `lib/fs/` | Size / `du` scans |
| `lib/windows/` | Windows path / Downloads defaults (→ platform in 00) |
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

## Commands (current binary)

```bash
./wslbkup --help
./wslbkup inspect
./tests/smoke.sh

# Optional: put on PATH
ln -sf "$PWD/wslbkup" ~/.local/bin/wslbkup
```

After phase 00: replace `wslbkup` with `linuxbkup` everywhere above.
