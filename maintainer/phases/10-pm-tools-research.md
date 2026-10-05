# Phase 10 — PM / tools / services path research (standing)

**Status:** **OPEN — does not fold until research is exhausted.**  
Not a Focus slot by default. Agents and humans use this doc as a living guide while shipping regenerable strips + restore install modules. Pull slices into Focus when implementing a capture/reinstall path.

## Goal

For every common Linux package manager, language toolchain, version manager, and related service/tool:

1. Map **config / state / identity** paths (must back up)
2. Map **install / cache / download** paths (regenerable — strip from backup)
3. Define **manifest capture** (what to record instead of the blobs)
4. Define **restore reinstall** (how to put it back without shipping gigabytes)

Doctrine: **never pack what `mise install` / `pip install` / `pnpm i` can recreate.** Archive rich schema + lockfiles + tool version pins; reinstall on restore.

## Standing rule

- This phase stays in `roadmap.md` as **open research** until explicitly closed.
- New host discoveries (e.g. another 2.6G under `share/*/installs`) get a row here **same session** as the regenerable strip.
- Implementation of a row → update `lib/constraints/regenerable.sh`, optional `modules/<tool>.sh`, `systems/constraints.md`, smoke when non-trivial.

## Research template (per tool)

| Field | Fill in |
|-------|---------|
| Tool | name + typical install method |
| Config (keep) | paths |
| State (keep / maybe) | paths + size notes |
| Installs / caches (strip) | paths |
| Manifest to capture | command or files |
| Restore reinstall | command sketch |
| linuxbkup status | researched / stripped / capture module / restore module |

## Findings (living)

### mise (researched — strip installs)

| Field | Detail |
|-------|--------|
| Config (keep) | `~/.config/mise/` (and project `mise.toml`) |
| State (keep) | `~/.local/state/mise/` — tiny (hints/history/trusted) |
| Strip | `~/.local/share/mise/installs/` (tool versions — multi‑GB), `…/downloads/` |
| Keep under share | `migrations/`, `shims/` (small; shims regenerable but cheap) |
| Manifest | `mise ls` / `mise ls --json` + config.toml |
| Restore | `mise install` from config |
| Status | **stripped** (installs/downloads); capture module later |

### Python user / venv installs (researched — strip blobs)

| Field | Detail |
|-------|--------|
| Strip | `~/.local/lib/python*/site-packages/`, project `venv` / `.venv`, `__pycache__`, `*.pyc`, `*.egg-info` |
| Keep | project sources, `requirements*.txt`, `pyproject.toml`, `poetry.lock`, `uv.lock`, `Pipfile.lock` |
| Manifest (later) | `pip freeze` / `uv pip freeze` / poetry export |
| Restore | recreate venv + install from lock/requirements |
| Status | **stripped** via regenerables; freeze capture TBD |

### pnpm / npm / yarn / bun (partial)

| Strip | `node_modules`, `~/.local/share/pnpm`, `~/.npm`, `.yarn/cache`, bun install cache |
| Keep | `package.json`, lockfiles, `.npmrc` |
| Restore | `pnpm i` / `npm ci` / `yarn` / `bun i` |
| Status | strip live; lockfile-based restore TBD |

### uv / pipx / rustup / cargo / go (partial)

| Strip | `~/.local/share/uv`, pipx venvs, `.cargo/registry\|git`, `.rustup`, `~/go/pkg`, `~/go/bin` |
| Keep | `Cargo.toml`/`Cargo.lock`, `go.mod`/`go.sum`, tool config |
| Status | strip live; manifests TBD |

### asdf / nvm / fnm / sdkman / rbenv (researched — strip installs)

| Field | Detail |
|-------|--------|
| Strip | `~/.asdf/installs|downloads`, `~/.nvm/versions`, `~/.local/share/fnm`, `~/.fnm`, `~/.sdkman/candidates|archives`, `~/.rbenv/versions`, `~/.rvm/rubies|gems` |
| Keep | `.tool-versions`, `.nvmrc`, sdkman config (not candidates), rbenv `version` files |
| Status | **stripped**; capture modules later |

### Flatpak / Snap / Distro PMs (todo)

| Distro | APT manuals already; dnf/pacman/apk modules later |
| Flatpak | app data vs app runtimes — research carefully |
| Status | APT capture live; rest **research** |

### IDE / agent runtimes (partial)

| Strip | `.cursor-server`, `.vscode-server`, JetBrains share caches, `.codex/.tmp` and other `.tmp` |
| Keep | IDE settings under `.config`, project `.vscode` when intentional |
| Status | strip expanding |

## Queued research (not started)

- Docker rootful vs rootless data roots
- Podman / container storage
- Cloudflare wrangler state vs cache (`.wrangler`)
- JVM (`~/.sdkman`, Gradle caches vs wrapper)
- Ruby `~/.rbenv`, `~/.rvm`
- PHP Composer home vs project vendor
- Nix profile vs store (never dump `/nix/store`)

## Slices (optional Focus pull-ins)

When pulling into Focus, name the tool:

- [ ] **10.mise** Capture `mise ls` + config into `packages/mise.*`
- [ ] **10.python** `pip`/`uv` freeze into packages/
- [ ] **10.nodejs** Detect package manager per project (later — restore phase)
- [x] **10.asdf-nvm** Strip parity with mise (asdf/nvm/fnm/sdkman/rbenv installs)
- [ ] **10.asdf-nvm-capture** Manifest capture modules (later)
- [ ] **10.flatpak** Honest gap report vs runtime dump

## Acceptance (for closing this phase — far future)

- Living table covers major desktop/VPS toolchains with keep/strip/manifest/restore
- Regenerable list and modules stay in sync with this doc
- No multi‑GB install trees appear in default backup stage on a mise+Python+Node host

## After each research landing

Update `regenerable.sh` + `systems/constraints.md` the same day. Do **not** mark this phase done in roadmap until the queued research list is empty or explicitly deferred.