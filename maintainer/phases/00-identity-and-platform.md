# Phase 00 — Identity + platform

**Goal:** Product is `linuxbkup` on any Linux host. Platform differences live under `lib/core/platform/`. No `wslbkup` legacy.

**Non-goals:** macOS primary support; keeping env/binary aliases for the old name.

## Locked

- Binary / CLI name: `linuxbkup`
- Env prefix (if any): `LINUXBKUP_*` only — **no** `WSLBKUP_*` shim
- Docs, comments, help, smoke scripts: say `linuxbkup` and “Linux (desktop, VPS, WSL)”
- Repo directory rename to `~/Tools/linuxbkup` is **yours** after plans land; code rename is this phase’s job when Focus opens it

## Why `lib/core/platform/`

Keeps capability probes out of command scripts and makes portability obvious:

```text
lib/core/platform/
  detect.sh      # linux | wsl | unknown; distro family already in lib/env
  paths.sh       # default archive dest, staging roots
  windows.sh     # optional: /mnt/c Downloads when present (move from lib/windows/)
  fs_space.sh    # free-space helpers used by space preflight
```

Rules:

- Commands call `platform_*` helpers; never hardcode `/mnt/c` in `lib/cmd/`
- Missing Windows mount → native defaults (`~/Backups/linuxbkup/`)
- Present Windows mount → may prefer Downloads under that mount (still override with `-o`)

## Slices

- [ ] **00.1** Rename entry `wslbkup` → `linuxbkup`; update dispatcher, smoke, AGENT, rules, guides references
- [ ] **00.2** Strip every `wslbkup` / `WSLBKUP` string (rg gate in smoke or a small check script)
- [ ] **00.3** Add `lib/core/platform/{detect,paths}.sh`; wire dest default
- [ ] **00.4** Move Windows path helpers under `lib/core/platform/windows.sh` (or thin wrapper); delete old `lib/windows/` when empty
- [ ] **00.5** Update `maintainer/systems/cli.md` + `shipped/` row for rename
- [ ] **00.6** Help text: “Works on desktop Linux, VPS, and WSL” + generic examples only

## Acceptance

- `./linuxbkup --help` works; no `wslbkup` binary required
- `rg -i 'wslbkup|WSLBKUP' --glob '!.git/**'` → empty (or only historical `maintainer/shipped` archive notes if we choose — prefer empty)
- On a host without `/mnt/c`, default output is under `$HOME/Backups/linuxbkup/`
- On WSL with `/mnt/c`, default may use Windows Downloads; `-o` always wins

## After ship

Fold into `shipped/` + `systems/cli.md` (+ new `systems/platform.md`).
