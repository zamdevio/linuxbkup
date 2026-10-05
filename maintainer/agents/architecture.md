# Architecture

Binary: **`linuxbkup`**. Env: **`LINUXBKUP_*`**. See shipped phase 00 (folded) + [`../systems/platform.md`](../systems/platform.md).

## 1. Topology

```text
linuxbkup               # argv dispatch
lib/
  core/
    common.sh           # globals, flag parse
    safety.sh           # confirm, force-overwrite, secrets/--yes gates
    context.sh          # per-command banner + tool gates
    help.sh             # styled help / version
    terminal/           # style, OSC 8 links, control
    platform/           # detect, paths, windows, fs_space
  cmd/                  # inspect backup restore verify list deps
  env/                  # distro, users, capabilities
  fs/                   # du / size scans
  classify/             # uses constraints
  constraints/          # path lists + list policy (→ rules in 02)
  tools/                # require + How-To from guides/
  backup/               # staging + home copy
  archive/              # tar.zst pack + checksums
guides/tools/
modules/                # apt, … (more phased)
tests/
docs/                   # end-user md (VitePress content)
apps/docs/              # PLANNED 07 — site → linuxbkup.pages.dev
maintainer/             # phases, systems, agents, shipped, temp
AGENT.md
```

## 2. Boundaries

- **CLI host** (`linuxbkup` + `lib/cmd/*.sh`) — argv, prompts, orchestration, reports
- **Core** (`lib/core/`) — flags, logging, safety, platform
- **Modules** — ecosystem detect + manifests
- **Constraints / classify** — what to scan/skip/secret
- **Unix tools** — `du`, `rsync`, `tar`, `zstd`, `sha256sum`, `age`, package managers
- **Docs site** — Node/VitePress only under `apps/docs`; **not** a CLI dependency
- **maintainer/** — control plane only

## 3. Safety model

- Uncertain → report + ask (redesign: `--ask`; profile suggests only)
- `--ask` wins over `--yes` (log ignore) — shipped phase 03
- `--dry-run` → zero modifications
- `--yes` → profile/non-TTY defaults; never silent plaintext secrets; never overwrite without `--force-overwrite`
- Soft fail detectors (`SKIP`/`WARN`); hard fail destination/corruption (`FATAL`)
- **Portable defaults:** no host-shaped home dirnames in shipped constraint lists
- **Filter stack:** `du` / rsync / plan sizes honor regenerable globs + user `--exclude`

## 4. Health gates

```bash
./tests/smoke.sh
bash -n linuxbkup lib/core/*.sh lib/core/platform/*.sh lib/cmd/*.sh
command -v shellcheck >/dev/null && shellcheck -x linuxbkup lib/core/*.sh lib/cmd/*.sh
```

No Node required to run the CLI.

## 5. Redesign pointer

[`../phases/redesign.md`](../phases/redesign.md) · tracker [`../phases/roadmap.md`](../phases/roadmap.md) · focus [`../phases/focus.md`](../phases/focus.md)
