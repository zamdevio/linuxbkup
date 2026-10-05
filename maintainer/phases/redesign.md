# Redesign — linuxbkup

Umbrella for the Linux-general backup redesign. **Plans only here until Focus says implement.**

After implementation lands, fold outcomes into [`../shipped/`](../shipped/) and [`../systems/`](../systems/), then **delete** the phase doc (see [`roadmap.md`](./roadmap.md) fold rule).

## Locked product rules

| Rule | Detail |
|------|--------|
| Identity | **`linuxbkup`** — multi-distro Linux CLI. WSL is one environment, not the brand. |
| No legacy | Clean identity only: binary, `LINUXBKUP_*` env, docs/comments. No old-name aliases or env shims. |
| Safety default | Conservative defaults (strict-leaning suggestions, confirm on TTY, secrets via `age`, space preflight). |
| Portability default | Archives + `schema.json` restore across machines/distros of the same family where possible; honest gap reports. |
| `--ask` > `--yes` | If both set: **ignore `--yes`**, print one log line, proceed interactive. |
| No personal examples | Placeholders only: `/home/user`, `~/Backups/linuxbkup/…`. |
| Portable defaults | No host-shaped home dirnames in shipped lists (`Projects`/`Workers`/`Tools`/…). |
| Filter stack | `du`, rsync, find, and plan sizes honor regenerable defaults + user `--exclude` (exclude wins). |
| Capability probes | Inspect detects common package managers/tools — presence only until restore modules exist. |
| fzf | Optional. Rich Bash numbered multi-select always. |
| Tracking | Implement → update `shipped/` + `systems/`; phase status in `roadmap.md`. |

## Phase index (live docs only)

| Doc | Topic | State |
|-----|--------|-------|
| [`05-space-schema.md`](./05-space-schema.md) | Schema field docs → fold into 06 | remaining: docs only |
| [`06-docs-content.md`](./06-docs-content.md) | `docs/*.md` ready for VitePress | planned |
| [`07-vitepress.md`](./07-vitepress.md) | `apps/docs` → https://linuxbkup.pages.dev | planned |
| [`10-pm-tools-research.md`](./10-pm-tools-research.md) | **Standing** PM/tools keep/strip/manifest map | open standing |
| [`refactor.md`](./refactor.md) | Layout hygiene — large files → subdirs + thin barrels | open (parallel) |
| [`focus.md`](./focus.md) | Active Focus (max 3) | — |
| [`roadmap.md`](./roadmap.md) | Shipped table + remaining only | — |

Shipped phases (00–04, 08, 09, 11, 12, …) are **folded** — outcomes live in `shipped/` + `systems/`.

## Discovery → backup (target)

```text
SCAN home → CLASSIFY → REPORT unexpected/large
  → DECIDE (--ask Bash/fzf | --yes profile defaults | non-TTY auto-include unknown)
  → RECLAIM / MARK-SECRET → SPACE → STAGE → schema+decisions → checksum → tar.zst
```

## Flag summary (target)

| Flag | Notes |
|------|--------|
| `--profile easy\|balanced\|strict` | Suggestions + `--yes` hard defaults |
| `--ask` | Interactive; wins over `--yes` |
| `-y, --yes` | Non-interactive; ignored if `--ask` present (logged) |
| `plan` / `plan --json` | Final include/skip/secret table (no writes); JSON envelope |
| `--keep-stage` / `--stage-dir` | Staging lifecycle |
| `--json` | Machine-readable plan/status |
| `--reclaim` / `--reclaim-all` | Bring back regenerable basenames |
| `--mark-secret` | Extra secret paths for `age` |
| `--exclude` / `--include` | Regex; exclude wins |
| `-o, --output` | Archive destination |

See also: [`roadmap.md`](./roadmap.md), [`focus.md`](./focus.md).
