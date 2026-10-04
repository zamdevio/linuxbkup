# Architecture — wslbkup

## 1. Topology

```text
wslbkup                 # argv dispatch, sources lib/core + lib/cmd
lib/
  core/                 # shared plumbing
    common.sh           # globals, flag parse, usage
    safety.sh           # confirm, force-overwrite, secrets/--yes gates
    context.sh          # per-command banner + tool gates
    terminal/
      style.sh          # ANSI + log_* + ui_*
      links.sh          # OSC 8 file:// / URL hyperlinks
      control.sh        # CSI/OSC helpers (cursor, reset, …)
  cmd/                  # one file per command (clean names)
    inspect.sh
    backup.sh
    restore.sh
    verify.sh
    list.sh
    deps.sh
  env/                  # distro, users, capabilities
  fs/                   # du / size scans
  windows/              # Downloads path resolution
  classify/             # uses constraints (no hardcoded lists)
  constraints/          # built-in path lists + list policy
  tools/                # require + How-To from guides/
  backup/               # staging + home copy
  archive/              # tar.zst pack + checksums
guides/tools/           # per-tool install guides (*.guide)
modules/                # apt, python, node, … (phased)
tests/
docs/
maintainer/             # control plane only
AGENT.md
```

Scaffolded as TS `packages/cli`, then replaced with this Bash layout (user request; scaffolder has no Bash preset).

## 2. Boundaries

- **CLI host** (`wslbkup` + `lib/cmd/*.sh`) — argv, prompts, orchestration, reports
- **Core** (`lib/core/`) — flags, logging, safety only
- **Modules** — capability detection + manifest capture/restore for one ecosystem
- **Rules** — data-driven classification (not hardcoded only in modules)
- **Unix tools** — `du`, `rsync`, `tar`, `zstd`, `sha256sum`, `age`, package managers do the heavy lifting
- **maintainer/** — phases/systems/agents only

## 3. Safety model

- Uncertain → report + ask
- `--dry-run` → zero modifications
- `--yes` → safe defaults only; never silent secrets-plain; never overwrite without `--force-overwrite`
- Optional detectors fail soft (`SKIP`/`WARN`); destination/corruption fail hard (`FATAL`)

## 4. Health gates

```bash
./tests/smoke.sh
bash -n wslbkup lib/core/*.sh lib/cmd/*.sh
command -v shellcheck >/dev/null && shellcheck -x wslbkup lib/core/*.sh lib/cmd/*.sh
```

No `pnpm` / TypeScript toolchain.
