# System — tool guides

Every tool the CLI **requires**, **optionally uses**, or **offers to install** must have a How-To at `guides/tools/<name>.guide`.

## Why

`linuxbkup deps howto <tool>` and missing-tool errors print install steps from these files. No guide → weak UX and fork pressure (“add my package manager / tool”).

## Format

Key=`value` lines (see any existing `.guide`):

| Key | Role |
|-----|------|
| `SUMMARY` | One-line purpose |
| `APT` / `DNF` / `YUM` / `PACMAN` / `APK` / `BREW` | Package name on that family |
| `HOW_*` | Full install command for that family |
| `NOTE` | Optional caveat |

## Catalog

| Tier | Source |
|------|--------|
| Core | `LINUXBKUP_DEPS_CORE` in `lib/tools/catalog.sh` |
| Optional | `LINUXBKUP_DEPS_OPTIONAL` (includes `fzf`, `age`, …) |
| Extra | Any other `guides/tools/*.guide` discovered on disk |

**Rule:** If you add a tool to core/optional **or** mention it in ask UI / docs as installable → add a matching `.guide` in the same change.

## Commands

```bash
linuxbkup deps
linuxbkup deps howto fzf
linuxbkup deps install fzf
```

## Permission note (ops)

Guides may show `sudo` for **installing packages**. Runtime backup/restore **never auto-sudo** for reading user files — unreadable paths soft-skip (see `lib/core/safety.sh`).
