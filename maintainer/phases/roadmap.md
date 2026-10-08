# Phase roadmap — linuxbkup

Progress tracker. Update when a phase lands or focus shifts.
See [`focus.md`](./focus.md) (max 3 active) and [`redesign.md`](./redesign.md) (locked redesign rules).

**Fold rule:** when a phase ships, delete its `phases/NN-*.md`, keep the outcome in [`../shipped/`](../shipped/) + matching [`../systems/`](../systems/). Partial phases stay here as a **remaining-work list only**.

## Identity

**linuxbkup** — Bash-first Linux backup/restore CLI (desktop, VPS, WSL; Alpine/iSH/Termux portability in progress).
Clean `linuxbkup` / `LINUXBKUP_*` identity (phase 00 — folded).

## Shipped (docs folded → shipped/ + systems/)

| Phase | Name | Notes |
|-------|------|-------|
| 0 | CLI skeleton | Dispatch, safety, globals, Bash layout |
| 1 | `inspect` | Distro/users/caps, du, classify, Downloads preview |
| — | Terminal UI | `lib/core/terminal/`, OSC 8 links, styled help |
| — | Constraints | Path lists + `--full`/`--top` |
| — | `deps` | status / install / howto + guides |
| 2 | `backup` core v1 | APT + allowlisted paths + tar.zst + checksums + verify |
| 00 | Identity + platform | `lib/core/platform/`, dest defaults, smoke identity gate |
| 01 | Verify staging | Archive or staging dir + checksums |
| 02 | Home scan + classify | Full-home scan; unexpected auto-include |
| 03 | Profiles / ask / flags | `--profile`, `--ask`>`--yes`, short aliases |
| 04 | Reclaim + secrets | age encrypt/decrypt; home/config rsync |
| 05 | Space + schema | Space gate + `schema.json` / `decisions.tsv`; **05.5 schema field docs** in `docs/schema.md` |
| 06 | Docs content | `docs/` end-user tree for linuxbkup (install → cli) |
| 07 | VitePress site | `apps/docs` → **https://linuxbkup.pages.dev** (see [`../systems/docs-site.md`](../systems/docs-site.md)) |
| 08 | Terminal UX | Progress, notify, tips, events.jsonl |
| 09 | UX fail-fast | Secrets preflight, byte estimates, banner, `ui_step` |
| 11 | Restore UX | Soft-quit reinstall batch, picker v2, failure re-run, R1 split |
| 12 | Reinstall hardening | Prefix extract, picker counts, pnpm allow-all-builds, workspace-root installs, interrupt boundary + nm auto-skip |
| 13 | Platform compat | Stage paths, Ctrl+Z restore/backup, tar/sha/rsync compat layer, atomic archives, deps bootstrap — see [`../shipped/`](../shipped/) + [`../systems/`](../systems/) |

## Open — remaining work only

| Phase | Doc | Remaining |
|-------|-----|-----------|
| 10 | [`10-pm-tools-research.md`](./10-pm-tools-research.md) | **OPEN standing** — keep/strip/manifest guide (do not fold early) |
| R | [`refactor.md`](./refactor.md) | **open (parallel)** — R-SMOKE then R2–R9; soft ≤250 / hard 400 |

**Soak (not a phase doc):** real iSH/Termux/Kali hardware run — checklist `maintainer/temp/13-soak-checklist.md`.

Later product phases: language modules (Python/Go reinstall), systemd/`/etc`, Docker — re-queue in focus when ready.

Optional parked: `/overview` site page for `docs/README.md`; further docs/SEO polish.

## Definition of done (Near-full)

Fresh Linux host (same package family) + `linuxbkup restore <archive>` gets packages, config, home, secrets (passphrase) close to the old env; report lists gaps; archive is portable **including BusyBox/minimal hosts** (phase 13); docs live at https://linuxbkup.pages.dev.

## Fold-back rule

When a phase ships → update [`../shipped/`](../shipped/) + [`../systems/`](../systems/) the same session, then **delete** the phase doc and point this table at shipped/.
