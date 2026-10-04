# Redesign — linuxbkup

Umbrella for the Linux-general backup redesign. **Plans only here until Focus says implement.**

After these phase docs are agreed and implementation lands, fold outcomes into [`../shipped/`](../shipped/) and [`../systems/`](../systems/).

## Locked product rules

| Rule | Detail |
|------|--------|
| Identity | **`linuxbkup`** — multi-distro Linux CLI. WSL is one environment, not the brand. |
| No legacy | Clean identity only: binary, `LINUXBKUP_*` env, docs/comments. No old-name aliases or env shims. |
| Safety default | Conservative defaults (strict-leaning suggestions, confirm on TTY, secrets via `age`, space preflight). |
| Portability default | Archives + `schema.json` restore across machines/distros of the same family where possible; honest gap reports. |
| `--ask` > `--yes` | If both set: **ignore `--yes`**, print one log line, proceed interactive. |
| No personal examples | Placeholders only: `/home/user`, `~/Backups/linuxbkup/…`. |
| Portable defaults | No host-shaped home dirnames in shipped lists (`Projects`/`Workers`/`Tools`/…). Until phase 02 full scan: backup defaults = shell/dotfiles + `.config` / `.local/bin` / secrets paths; extra trees via `--include`. |
| Filter stack | `du`, rsync, find, and plan sizes honor regenerable defaults + user `--exclude` (exclude wins). Never report “backup size” that includes ignored regenerables. |
| Capability probes | Inspect detects common package managers, tool managers, process managers, web servers, databases, containers/cloud CLIs — presence only until restore modules exist. |
| fzf | Optional. Rich Bash numbered multi-select always. |
| Tracking | Implement → update `shipped/` + `systems/`; phase status in `roadmap.md`. |

## Phase index

| Doc | Topic |
|-----|--------|
| [00-identity-and-platform.md](./00-identity-and-platform.md) | Rename, `lib/core/platform/`, dest defaults |
| [01-verify-staging.md](./01-verify-staging.md) | Verify staging dirs |
| [02-home-scan-classify.md](./02-home-scan-classify.md) | Full HOME + unexpected paths |
| [03-profiles-ask-flags.md](./03-profiles-ask-flags.md) | Profiles, ask UI, useful flags |
| [04-reclaim-secrets.md](./04-reclaim-secrets.md) | Reclaim regenerables + mark-secret/`age` |
| [05-space-schema.md](./05-space-schema.md) | Space gates + reversible schema |
| [06-docs-content.md](./06-docs-content.md) | `docs/*.md` ready for VitePress |
| [07-vitepress.md](./07-vitepress.md) | `apps/docs` → https://linuxbkup.pages.dev |
| [08-terminal-ux.md](./08-terminal-ux.md) | Progress, OSC links, notify, flag-aware tips |

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
| `plan` / `plan --json` | Show final include/skip/secret table (no writes); JSON envelope |
| `--keep-stage` | Keep staging after success |
| `--stage-dir <path>` | Staging location |
| `--json` | Machine-readable plan/status |
| `--reclaim` / `--reclaim-all` | Bring back regenerable basenames |
| `--mark-secret` | Extra secret paths for `age` |
| `--exclude` / `--include` | Regex; exclude wins |
| `-o, --output` | Archive destination |

See also: [`roadmap.md`](./roadmap.md), [`focus.md`](./focus.md).
