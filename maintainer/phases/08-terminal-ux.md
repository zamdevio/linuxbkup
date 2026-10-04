# Phase 08 — Terminal UX (progress, links, notifications)

**Goal:** Solid terminal presentation for long-running ops — live progress, OSC 8 links, optional desktop/terminal notifications — without depending on a specific emulator. **Rich internal data must surface in the UI** (sizes, classes, stage footprint, limits), not sit unused after classify/scan.

**Non-goals:** TUI frameworks; forcing color/links in pipes; auto-sudo prompts via OSC.

## Locked

| Surface | Behavior |
|---------|----------|
| Progress | TTY: single-line `\r` bar + `current/total` + truncated path + **live stage size** (+ `/ max` when `--max-size`). Non-TTY: periodic INFO lines. Quiet suppresses. |
| Lists | Prefer **size + class + path**; order **large → small** when sizes known. Truncate via `-T`/`-F`. |
| Links | Existing OSC 8 (`lib/core/terminal/links.sh`); `--no-links` / non-TTY safe |
| Notify | Best-effort end-of-run notify (OSC 9 / OSC 777 / `notify-send` when present). Never required. |
| Control | Cursor hide/show around live progress; always restore on EXIT / interrupt |
| Errors | Clear fatals for `--max-size`, missing dest, copy abort; soft-skip perms; cursor always restored |

## Doctrine — use the data

Classify/scan/du already produce size, class, action, reason. Every human list (plan sections, backup “Paths to copy”, unexpected decide) should **show that richness** and sort by size when possible. Progress meters the **staging directory** in real time. Tips replay the flags that produced the plan.

## Modules

```text
lib/core/terminal/
  style.sh      # logs + ui_*
  links.sh      # OSC 8
  control.sh    # CSI helpers
  progress.sh   # live bar / stage bytes / step updates
  notify.sh     # optional completion ping
lib/core/cli_tips.sh   # plan↔backup flag replay
lib/fs/sizes.sh        # du + parse/human helpers (--max-size)
```

## Related product flags (shipped with this UX)

| Flag | Meaning |
|------|---------|
| `--max-size SIZE` | Hard limit on **uncompressed staging** footprint (not final `.tar.zst`). Fail early on estimate or mid-copy. |

Default-skip regenerable `~/go`; `/tmp` is **not** in default inspect size targets (no special casing — just absent).

## Slices

- [x] **08.1** `progress.sh` — begin/update/end; TTY vs non-TTY
- [x] **08.2** `notify.sh` — best-effort notify on backup success
- [x] **08.3** Wire backup copy + checksum + pack steps to progress
- [x] **08.4** Flag replay helper for `plan`↔`backup` tips
- [x] **08.5** `systems/terminal.md` + smoke that progress helpers are loadable
- [x] **08.6** Live stage bytes on progress; `--max-size`; lists large→small with size/class
- [x] **08.7** Skip `~/go` by default; drop `/tmp` from default size scan

## Acceptance

- `linuxbkup -y backup` shows live path progress + stage size on a TTY
- “Paths to copy” / plan lists ordered large → small when sizes known
- Piped stdout does not emit `\r` spam
- Tips include the same include/exclude/secret/`--max-size` flags the user passed
- Cursor restored after interrupt; `--max-size` abort is fatal and clear

## After ship

`systems/terminal.md` + `systems/constraints.md` + `shipped/`.
