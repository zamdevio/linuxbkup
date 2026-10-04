# Architecture — wslbkup

## 1. Topology

```text
wslbkup                 # argv dispatch, sources lib/core + lib/cmd
lib/
  core/                 # shared plumbing
    common.sh           # globals, flag parse, usage
    logging.sh          # OK / WARN / SKIP / FATAL / INFO / DEBUG
    safety.sh           # confirm, force-overwrite, secrets/--yes gates
  cmd/                  # one file per command (clean names)
    inspect.sh
    backup.sh
    restore.sh
    verify.sh
    list.sh
  # later, same style — group by concern, not flat prefixes:
  #   fs/  archive/  manifest/  secrets/  windows/
modules/                # apt, python, node, rust, go, ruby, services, docker, …
rules/                  # regenerable / include / secrets patterns
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
