---
description: Clone the repo, check dependencies, optionally put linuxbkup on PATH, then run your first plan or backup.
---

# Install

linuxbkup is a single Bash binary. No `npm install`, no virtualenv, no compile step for the CLI itself.

## Requirements

| Tool | Required? | Notes |
|------|-----------|--------|
| `bash` | Yes | 4+ |
| `tar` | Yes | GNU or BusyBox (compat layer probes flags) |
| `zstd` | Yes | Archive compression |
| `rsync` | Yes | Home/config copy + restore |
| `du`, `find` | Yes | Size scans + classification |
| `sha256sum` **or** `shasum` **or** `openssl` | Yes (any one) | Checksums |
| `age` | Optional | Secrets subset |
| `fzf` | Optional | Interactive picker nicety |

Missing tools: `linuxbkup deps` prints How-Tos; `deps install` can bootstrap via **apk · apt · pacman · pkg (Termux) · dnf · yum · brew**.

## Get the source

```bash
git clone https://github.com/zamdevio/linuxbkup.git
cd linuxbkup
```

Or copy an existing checkout onto the target host (the tree is portable).

## Put it on PATH (optional)

```bash
ln -sf "$PWD/linuxbkup" ~/.local/bin/linuxbkup
# ensure ~/.local/bin is on PATH
linuxbkup --help
```

The symlink must point at the **real repo binary**. `linuxbkup` resolves `readlink -f` so `LINUXBKUP_ROOT` is the checkout (where `lib/` lives), not `~/.local/bin`.

Copying only the `linuxbkup` file without `lib/` fails fast:

```text
linuxbkup: cannot find lib/ under /path/to/wherever
```

Keep the full tree (git clone) and re-link if you move it.

## First commands

```bash
./linuxbkup --help
./linuxbkup version
./linuxbkup inspect          # environment + default destination
./linuxbkup deps status      # what is installed / missing
./linuxbkup plan             # what a backup would include/skip
```

## Smoke test (optional)

```bash
./tests/smoke.sh
```

Expect `OK` lines for help, syntax, fixtures, compat probes, and interrupt proofs. On very large `$HOME` trees, dry-run/plan steps that walk the home directory can take a while — that is classification cost, not a hang.

## Typical install loop

```bash
./linuxbkup deps install          # missing core tools
./linuxbkup -y --dry-run backup   # plan only
./linuxbkup -y backup             # real archive
```

Archives land in `~/Backups/linuxbkup/` by default (or Windows Downloads when a WSL mount resolves). Override with `-o /path/to/archive.tar.zst`.

Next: [Concepts](./concepts.md) · [Guide](./guide.md)
