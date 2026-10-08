# Systems — current map

How subsystems wire together as the tree is today. Redesign targets: [`../phases/redesign.md`](../phases/redesign.md).

| Doc | Status |
|-----|--------|
| [cli.md](./cli.md) | Live — `linuxbkup` dispatch + interrupt API + phase 13 notes |
| [platform.md](./platform.md) | Live — platform + **compat layer + stage paths (13)** |
| [inspect.md](./inspect.md) | Live |
| [constraints.md](./constraints.md) | Live (allowlist-oriented; redesign → rule-based full home) |
| [tools.md](./tools.md) | Live — deps + guides + **compat probes + bootstrap (13)** |
| [guides.md](./guides.md) | Live — every tool needs a `.guide` |
| [terminal.md](./terminal.md) | Live — progress, links, notify, tips |
| [backup-restore.md](./backup-restore.md) | Live — backup/restore/verify + **atomic packs + stage paths (13)** |
| [docs-site.md](./docs-site.md) | Live — VitePress `apps/docs` → https://linuxbkup.pages.dev |

Shipped phases fold into [`../shipped/`](../shipped/) + the matching system doc above. Phases 05–07 (docs + site) and 13 platform compat are **shipped**.
