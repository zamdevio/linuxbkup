# Shipped

What has actually landed (not aspirational).

| When | What |
|------|------|
| Phase 0 | `wslbkup` dispatcher, `lib/core`, stub commands, smoke |
| Phase 1 | Real `inspect` (env/fs/classify/windows) |
| UX | `lib/core/terminal/` style + OSC 8 links |
| UX | `lib/constraints/` + include/exclude + list policy |
| UX | `deps status \| install \| howto` + `guides/tools/*.guide` |
| UX | Styled `--help` / `help <cmd>` / `version` |
| Phase 2 | `backup` staging → APT manifests → home/config rsync → tar.zst + checksums |
| Phase 2 | `verify` extracts + checks `checksums.sha256` |

Next ship target: Phase 3 secrets/`age` (see [`../phases/roadmap.md`](../phases/roadmap.md)).
