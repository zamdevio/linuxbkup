# System — terminal UX

`lib/core/terminal/` — presentation for humans on a TTY.

| File | Role |
|------|------|
| `style.sh` | Structured logs + `ui_*` + `ui_step` (parks live line before emit) |
| `links.sh` | OSC 8 path/URL hyperlinks |
| `control.sh` | CSI on stderr; cursor via `/dev/tty` + `tput cnorm`; `term_live_park` / `linuxbkup_tty_restore` |
| `progress.sh` | Live `\r`+EL2 bar on **stderr**; stage bytes; INFO steps when piped |
| `notify.sh` | Best-effort completion notify (`notify-send` / OSC 9 / OSC 777) |
| `events.sh` | Structured step events (jsonl + verbose); `ui_step_event` pairs with labels |

## Rules

- Progress/notify respect `--quiet`; links respect `--no-links`
- Live bar is stderr-only so stdout stays pipe-clean; `term_live_park` before durable logs
- Cursor always restored (`linuxbkup_tty_restore` on EXIT / interrupt / command end)
- Notifications never required for correctness (`LINUXBKUP_NO_NOTIFY=1` disables)
- **Use rich data:** lists show size + class + path; order large → small when sizes known
- Progress samples staging dir (`du -sb`) and shows `--max-size` headroom when set
- **Upstream → downstream:** probe/classify once → UI + manifests share the same snapshot. Backup shows capability sections before staging; `metadata/events.jsonl` records step start/ok/fail for the run. Capture modules (APT today, more later) run *after* detect.

Signals / interrupt menu: see [`cli.md`](./cli.md) (central API in `lib/core/interrupt.sh`).

## Flag tips

`lib/core/cli_tips.sh` rebuilds copy-pasteable `linuxbkup … plan|backup` lines from current globals (include/exclude/secrets/user/list/`-y`/`--max-size`/…, plus `-o` for backup tips).

## Phase

phase 08 (folded — see [`../shipped/`](../shipped/))
