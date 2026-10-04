# Shipped

What has actually landed (not aspirational). Binary: **`linuxbkup`**. Env: **`LINUXBKUP_*`**.

| When | What |
|------|------|
| Phase 0 | Dispatcher, `lib/core`, stub commands, smoke |
| Phase 1 | Real `inspect` (`lib/env`, `lib/fs`, classify, dest preview) |
| UX | `lib/core/terminal/` style + OSC 8 links |
| UX | `lib/constraints/` + include/exclude + list policy |
| UX | `deps status \| install \| howto` + `guides/tools/*.guide` |
| UX | Styled `--help` / `help <cmd>` / `version` |
| Phase 2 | `backup`: staging → APT manuals → allowlisted home/config rsync → `tar.zst` + checksums |
| Phase 2 | `verify` on `*.tar.zst` (extract + `checksums.sha256`) |
| Phase 2 | INDEX write survives `pipefail`; staging kept on pack failure (`32b5b11`) |
| Phase 00 | Identity `linuxbkup` + `LINUXBKUP_*`; `lib/core/platform/` (detect, paths, windows, fs_space); native dest `~/Backups/linuxbkup/`; smoke identity gate |
| UX | Portable backup/important lists (no host-shaped dirnames); filter stack for `du` + rsync; broader inspect capability probes |

## Not shipped yet (redesign track)

| Item | Phase doc |
|------|-----------|
| Verify staging directories | [01](../phases/01-verify-staging.md) |
| Full HOME scan + unexpected paths | [02](../phases/02-home-scan-classify.md) |
| Profiles / ask UI / print-plan / json / stage flags | [03](../phases/03-profiles-ask-flags.md) |
| Reclaim + secrets/`age` | [04](../phases/04-reclaim-secrets.md) |
| Space preflight + `schema.json` | [05](../phases/05-space-schema.md) |
| `docs/*` rewrite | [06](../phases/06-docs-content.md) |
| VitePress → https://linuxbkup.pages.dev | [07](../phases/07-vitepress.md) |

Umbrella: [`../phases/redesign.md`](../phases/redesign.md). When a phase lands, add a row here and update the matching `systems/` doc in the same change.
