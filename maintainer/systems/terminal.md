# System — terminal UX

`lib/core/terminal/` — presentation for humans on a TTY.

| File | Role |
|------|------|
| `style.sh` | Structured logs + `ui_*` |
| `links.sh` | OSC 8 path/URL hyperlinks |
| `control.sh` | CSI: clear EOL, cursor hide/show |
| `progress.sh` | Live `\r` progress bar (TTY); stage bytes; INFO steps when piped |
| `notify.sh` | Best-effort completion notify (`notify-send` / OSC 9 / OSC 777) |

## Rules

- Progress/notify respect `--quiet`; links respect `--no-links`
- Piped stdout: no `\r` spam; cursor always restored after progress
- Notifications never required for correctness (`LINUXBKUP_NO_NOTIFY=1` disables)
- **Use rich data:** lists show size + class + path; order large → small when sizes known
- Progress samples staging dir (`du -sb`) and shows `--max-size` headroom when set
- **Upstream → downstream:** probe/classify once → UI + manifests share the same snapshot. Backup should show inspect-class capability sections before staging (slices 08.8–08.10); capture modules (APT today, more later) run *after* that display.

## Flag tips

`lib/core/cli_tips.sh` rebuilds copy-pasteable `linuxbkup … plan|backup` lines from current globals (include/exclude/secrets/user/list/`-y`/`--max-size`/…, plus `-o` for backup tips).

## Phase

[`../phases/08-terminal-ux.md`](../phases/08-terminal-ux.md)
