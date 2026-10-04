# Agent rules — wslbkup

1. Product code lives in `wslbkup`, `lib/`, `modules/`, `rules/`, `tests/`. Do not reintroduce Node/pnpm CLI unless asked.
2. `maintainer/*` is the control plane.
3. `maintainer/temp` is scratch and gitignored — never commit it.
4. Keep focus.md at max 3 active verticals. Phase by phase.
5. Prefer small, verified steps (`./tests/smoke.sh`, `bash -n`).
6. **Do not commit or push unless the user explicitly asks** — see [`git.md`](./git.md).
