# Phase roadmap — linuxbkup

Progress tracker. Update when a phase lands or focus shifts.
See [`focus.md`](./focus.md) (max 3 active) and [`redesign.md`](./redesign.md) (locked redesign rules).

## Identity

**linuxbkup** — Bash-first Linux backup/restore CLI (desktop, VPS, WSL).  
Clean `linuxbkup` / `LINUXBKUP_*` identity (phase 00).

## Historical (pre-redesign)

| Phase | Name | Status | Notes |
|-------|------|--------|-------|
| 0 | CLI skeleton | **done** | Dispatch, safety, globals, Bash layout |
| 1 | `inspect` | **done** | Distro/users/caps, du, classify, Downloads preview |
| — | Terminal UI | **done** | `lib/core/terminal/`, OSC 8 links, styled help |
| — | Constraints | **done** | Path lists + `--full`/`--top` (to be rule-based in redesign 02) |
| — | `deps` | **done** | status / install / howto + guides |
| 2 | `backup` core | **done (v1)** | APT + allowlisted paths + tar.zst + checksums + verify |
| — | INDEX/pipefail | **done** | Staging kept on pack failure (`32b5b11`) |

## Redesign track (planned)

| Phase | Doc | Status |
|-------|-----|--------|
| 00 | [Identity + platform](./00-identity-and-platform.md) | **done** |
| 01 | [Verify staging](./01-verify-staging.md) | **done** |
| 02 | [Home scan + classify](./02-home-scan-classify.md) | **done** |
| 03 | [Profiles, ask, flags](./03-profiles-ask-flags.md) | **done** |
| 04 | [Reclaim + secrets](./04-reclaim-secrets.md) | **done** (encrypt + decrypt + home/config rsync) |
| 05 | [Space + schema](./05-space-schema.md) | **in progress** (space gate; schema later) |
| 06 | [Docs content](./06-docs-content.md) | planned |
| 07 | [VitePress → pages.dev](./07-vitepress.md) | planned |
| 08 | [Terminal UX](./08-terminal-ux.md) | **done** (through 08.10 events.jsonl) |
| 09 | [UX fail-fast](./09-ux-failfast.md) | **in progress** (09.1–09.3/09.6 done; banner later) |
| 10 | [PM/tools research](./10-pm-tools-research.md) | **OPEN standing** — living keep/strip/manifest guide (do not fold) |
| R | [Refactor / large-file split](./refactor.md) | **planned** — barrel + `lib/**/<name>/*.sh`; soft ≤250 / hard 400 lines |

Later product phases (after redesign foundation): restore polish, language modules, systemd/`/etc`, Docker — re-queue in focus when ready.

## Definition of done (Near-full)

Fresh Linux host (same package family) + `linuxbkup restore <archive>` gets packages, config, home, secrets (passphrase) close to the old env; report lists gaps; archive is portable; docs live at https://linuxbkup.pages.dev.

## Fold-back rule

When a redesign phase ships → update [`../shipped/`](../shipped/) and the matching [`../systems/`](../systems/) doc the same PR/session.
