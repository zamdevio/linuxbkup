<div align="center">
  <img src="https://linuxbkup.pages.dev/linuxbkup.svg" width="72" height="72" alt="linuxbkup logo" />

  <h1>linuxbkup</h1>

  [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
  [![Bash](https://img.shields.io/badge/Bash-first-4EAA25?logo=gnubash&logoColor=white)](./linuxbkup)
  [![No runtime](https://img.shields.io/badge/No%20Node%2FPython%20runtime-000000?logo=linux&logoColor=white)](./docs/concepts.md)
  [![Linux · WSL](https://img.shields.io/badge/Linux-Desktop%20%C2%B7%20VPS%20%C2%B7%20WSL-FCC624?logo=linux&logoColor=black)](./docs/platforms.md)
  [![Alpine · Termux](https://img.shields.io/badge/Alpine%20%C2%B7%20Termux-best%20effort-0D597F?logo=alpinelinux&logoColor=white)](./docs/platforms.md)
  [![Atomic archives](https://img.shields.io/badge/Archives-atomic%20tar.zst-6F42C1)](./docs/schema.md)

  <p><strong>Universal Linux backup — Bash + coreutils + a few small tools.</strong></p>
  <p>
    Scan a home directory, classify what matters, stage it, pack an atomic
    <code>tar.zst</code> with checksums, and restore it on another machine —
    without a Node/Python runtime, a backup daemon, or a distro-specific fork.
  </p>
  <p>
    <a href="https://linuxbkup.pages.dev">Docs</a> ·
    <a href="https://github.com/zamdevio/linuxbkup">GitHub</a> ·
    <a href="./docs/guide.md">Guide</a>
  </p>
</div>

---

**linuxbkup** is a single Bash binary that orchestrates tools you already have — `du`, `find`, `tar`, `zstd`, `rsync`, optional `age`. Same CLI on desktop Linux, a VPS, WSL, and (best-effort) Alpine / iSH / Termux. `linuxbkup deps` detects your package manager and bootstraps what is missing.

| Surface | Path | Role |
|---------|------|------|
| **CLI** | [`linuxbkup`](./linuxbkup) | `inspect` · `plan` · `backup` · `restore` · `verify` · `deps` |
| **Docs** | [`docs/`](./docs/README.md) | Install, concepts, guide, platforms, schema, secrets, CLI |
| **Smoke** | [`tests/smoke.sh`](./tests/smoke.sh) | Thin runner — syntax, fixtures, compat, interrupt proofs |
| **Compat** | [`lib/core/compat/`](./lib/core/compat/compat.sh) | tar / sha / rsync probes + portable flag wrappers |

## Quick start

```bash
git clone https://github.com/zamdevio/linuxbkup.git && cd linuxbkup
./linuxbkup deps          # see what's missing; bootstrap if needed
./linuxbkup plan          # what would be included / skipped (no writes)
./linuxbkup -y backup     # scan → stage → atomic tar.zst
./linuxbkup verify ~/Backups/linuxbkup/<archive>.tar.zst
./linuxbkup -k -f restore ~/Backups/linuxbkup/<archive>.tar.zst
```

Optional on `PATH` (symlink into a **full checkout** — the CLI resolves the real path to find `lib/`):

```bash
ln -sf "$PWD/linuxbkup" ~/.local/bin/linuxbkup
# ensure ~/.local/bin is on PATH
linuxbkup --help
```

If you only copy the `linuxbkup` file without the repo tree, it exits with `cannot find lib/…` and prints the re-link hint.

| Command | What it does |
|---------|----------------|
| `linuxbkup inspect` | Distro, users, tools, default destination |
| `linuxbkup plan` | Include/skip table + `--json` (read-only) |
| `linuxbkup -y backup` | Full-home classify → stage → checksum → `tar.zst` |
| `linuxbkup verify <archive\|stage>` | Integrity + manifest soft-checks |
| `linuxbkup -k -f restore <archive>` | Extract → secrets → home/config; Node reinstalls from manifest |
| `linuxbkup deps install` | One-command bootstrap (apk / apt / pacman / pkg / …) |

## Why this exists

Backup tools are either **too heavy** (agents, daemons, Node stacks, cloud lock-in) or **too thin** (a `tar` alias that silently skips your config). linuxbkup sits in the middle on purpose:

| You get | You do **not** need |
|---------|---------------------|
| Full-home scan + unexpected-path reporting | A running backup service |
| Regenerable strip (`node_modules`, venvs, caches, …) | Guesswork about what to skip |
| Atomic `tar.zst` + `checksums.sha256` | A custom archive format |
| Secrets subset via `age` | A secrets manager |
| Restore that rebuilds `node_modules` from a manifest | Ansible / cloud agents |
| Portability across distros via a compat layer | A different binary per host |
| Bash-first core | Node, Python, or a package manager for the CLI itself |

**Heavy work in little time.** Classification, parallel checksums (`-w`), and `zstd` threads do the expensive parts. The product code is shell — readable, greppable, no compile step, no `node_modules` to ship with the binary.

## How a backup runs

```text
inspect/plan  →  classify home  →  stage  →  seal (secrets, INDEX, checksums)
             →  pack tar.zst (tmp → verify → rename)  →  summary
restore       →  extract (path printed)  →  decrypt secrets
             →  rsync home/config  →  Node reinstalls from manifest
```

Safety is default, not a flag:

- Restore overwrite requires `-f/--force-overwrite` (`--yes` alone is never enough)
- `--yes` backup still requires a secrets passphrase (env) or an explicit `--no-secrets` / `--secrets-plain`
- Archives never land as a partial `.tar.zst` — pack writes `*.tmp`, verifies, then renames
- Ctrl+C → menu (retry / skip / quit). Ctrl+Z suspends the whole job on backup **and** restore

## Hosts

| Host | Status |
|------|--------|
| GNU Linux (desktop / VPS / WSL) | Happy path |
| Alpine / BusyBox | tar flag fallbacks; `deps` + `zstd` required |
| iSH / Termux | Best-effort — no FHS assumptions; run `deps` first |
| FAT / exFAT / NTFS / 9p mounts | rsync metadata mode (no chmod/symlink hard-fail) |

Checksums accept `sha256sum` **or** `shasum -a 256` **or** `openssl dgst`. Tar impl is probed (GNU / BusyBox / BSD). Details: [`docs/platforms.md`](./docs/platforms.md).

## Defaults (locked)

- Archive: `~/Backups/linuxbkup/<distro>-<timestamp>.tar.zst` (or Windows Downloads when a WSL mount resolves); override with `-o`
- Staging / extract paths always printed; same naming family for backup, restore, verify
- Secrets: `age` subset; passphrase via `LINUXBKUP_SECRETS_PASS` / `_PASS_FILE` or TTY
- Env prefix: `LINUXBKUP_*` only
- Examples in docs use generic paths (`/home/user`, `~/Backups/linuxbkup/…`)

## Docs

| Doc | Topic |
|-----|--------|
| [`docs/install.md`](./docs/install.md) | Clone, `deps`, PATH, first commands |
| [`docs/concepts.md`](./docs/concepts.md) | Regenerable vs backup, safety model, portability |
| [`docs/guide.md`](./docs/guide.md) | inspect → plan → backup → verify → restore |
| [`docs/platforms.md`](./docs/platforms.md) | Desktop, VPS, WSL, Alpine, Termux |
| [`docs/schema.md`](./docs/schema.md) | Archive layout + `schema.json` |
| [`docs/secrets.md`](./docs/secrets.md) | age encryption + `--yes` rules |
| [`docs/troubleshooting.md`](./docs/troubleshooting.md) | Common failures |
| [`docs/cli.md`](./docs/cli.md) | Full command reference |

A hosted docs site (VitePress → Cloudflare Pages) is **live**: [linuxbkup.pages.dev](https://linuxbkup.pages.dev). This repo’s [`docs/`](./docs/README.md) is the source of truth.

## Layout

```text
linuxbkup                 CLI entry (bin)
lib/core/                 common, safety, interrupt, context, help
lib/core/compat/          tar/sha/rsync/numfmt probes + wrappers
lib/core/terminal/        style, OSC 8 links, progress, events
lib/core/platform/        detect, dest paths, WSL mount helpers
lib/cmd/                  inspect, plan, backup, restore, verify, list, deps
lib/backup/               staging, home copy, restore, reinstall/
lib/archive/              tar.zst pack, checksums, verify
lib/constraints/          include/exclude + list policy
lib/env/ lib/fs/ lib/classify/ lib/tools/
modules/                  apt, node, …
guides/tools/             per-tool install How-Tos
tests/                    smoke runner + fixtures
docs/                     end-user documentation
```

Contributor / agent entry: [`AGENT.md`](./AGENT.md).

## License

[MIT](./LICENSE)
