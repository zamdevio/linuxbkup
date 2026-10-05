# Agent rules

1. Product code: `linuxbkup`, `lib/`, `modules/`, `guides/`, `tests/`. Core CLI stays Bash — no Node/Python runtime. `apps/docs` may use Node for VitePress only.
2. `maintainer/*` is the control plane. Implement only what [`../phases/focus.md`](../phases/focus.md) opens (max 3).
3. Redesign slices: [`../phases/redesign.md`](../phases/redesign.md) + `00`–`07`. After ship → update [`../shipped/`](../shipped/) and matching [`../systems/`](../systems/) docs.
4. Identity: binary `linuxbkup`, env `LINUXBKUP_*` only — no old-name aliases or env shims.
5. `maintainer/temp` is scratch and gitignored — never commit it.
6. Prefer small verified steps (`./tests/smoke.sh`, `bash -n`).
7. Examples: generic paths only (`/home/user`, …).
8. **Do not commit or push unless the user explicitly asks** — see [`git.md`](./git.md).
9. **Layout budget:** soft ≤250 lines/file, hard cap 400. Over cap → split into `lib/**/<name>/*.sh` with a thin barrel at the old path (see [`../phases/refactor.md`](../phases/refactor.md)). Call sites keep sourcing the barrel. Smoke suite splits the same way (`tests/smoke/*.sh` + thin `tests/smoke.sh` runner) — **parallel** track, not a Focus slot.
10. **Restore interrupt parity:** all `restore` ops (extract → secrets → files → reinstalls) must use the central interrupt API (`op_begin` + `without_monitor` + menu) like backup; picker v2 modes in [`../phases/11-restore-ux.md`](../phases/11-restore-ux.md).
