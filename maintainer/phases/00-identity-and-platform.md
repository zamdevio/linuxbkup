# Phase 00 — Identity + platform

**Goal:** Product is `linuxbkup` on any Linux host. Platform differences live under `lib/core/platform/`. Clean identity only — no old-name binary aliases or env shims.

**Non-goals:** macOS primary support; keeping aliases for a previous product name.

## Locked

- Binary / CLI name: `linuxbkup`
- Env prefix: `LINUXBKUP_*` only — no shims for any prior prefix
- Docs, comments, help, smoke scripts: say `linuxbkup` and “Linux (desktop, VPS, WSL)”
- Repo directory at `~/Tools/linuxbkup` is operator-owned; code identity is this phase’s job

## Why `lib/core/platform/`

Keeps capability probes out of command scripts and makes portability obvious:

```text
lib/core/platform/
  detect.sh      # linux | wsl | unknown; distro family already in lib/env
  paths.sh       # default archive dest, staging roots
  windows.sh     # optional: /mnt/c Downloads when present
  fs_space.sh    # free-space helpers used by space preflight
```

Rules:

- Commands call `platform_*` helpers; never hardcode `/mnt/c` in `lib/cmd/`
- Missing Windows mount → native defaults (`~/Backups/linuxbkup/`)
- Present Windows mount → may prefer Downloads under that mount (still override with `-o`)

## Slices

- [x] **00.1** Rename CLI entry to `linuxbkup`; update dispatcher, smoke, AGENT, rules, guides references
- [x] **00.2** Strip every previous-product-name / prior-env-prefix string (rg gate in smoke; pattern assembled at runtime)
- [x] **00.3** Add `lib/core/platform/{detect,paths}.sh`; wire dest default
- [x] **00.4** Windows path helpers under `lib/core/platform/windows.sh`; remove empty `lib/windows/`
- [x] **00.5** Update `maintainer/systems/cli.md` + `shipped/` row for rename
- [x] **00.6** Help text: “Works on desktop Linux, VPS, and WSL” + generic examples only

## Acceptance

- `./linuxbkup --help` works; previous-name binary not required
- Smoke identity gate: previous product name / env prefix → empty in tree
- On a host without `/mnt/c`, default output is under `$HOME/Backups/linuxbkup/`
- On WSL with `/mnt/c`, default may use Windows Downloads; `-o` always wins

## After ship

Fold into `shipped/` + `systems/cli.md` (+ new `systems/platform.md`).
