# Phase roadmap — wslbkup

Progress tracker. Update when a phase lands or focus shifts.
See also [`focus.md`](./focus.md) (max 3 active).

| Phase | Name | Status | Notes |
|-------|------|--------|-------|
| 0 | CLI skeleton | **done** | Dispatch, safety, globals, Bash layout |
| 1 | `inspect` | **done** | Distro/users/caps, du, classify, Downloads preview |
| — | Terminal UI | **done** | `lib/core/terminal/`, OSC 8 links, styled help |
| — | Constraints | **done** | `lib/constraints/`, include/exclude, `--full`/`--top` |
| — | `deps` | **done** | status / install / howto + guides |
| 2 | `backup` core | **next** | APT + home/config + tar.zst → Downloads |
| 3 | Secrets | queued | `age` passphrase over secrets subset |
| 4 | `restore` | queued | dry-run, compatibility, honest report |
| 5 | Language modules | queued | pip/npm/cargo/go/ruby |
| 6 | systemd + `/etc` | queued | selective allowlist |
| 7 | Docker + polish | queued | detect/decide, README, smoke depth |

## Done recently

- Scaffold → Bash pivot (`lib/core`, `lib/cmd`, …)
- Inspect + Windows Downloads default path
- Constraints + tool guides + `deps`
- Styled help/version matching log UI

## Definition of done (Near-full)

Fresh same-family WSL + `wslbkup restore <archive>` gets packages, globals, services, config, home, secrets (passphrase) close to the old env; report lists gaps; archive survives under Windows Downloads.
