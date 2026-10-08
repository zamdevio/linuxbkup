---
description: First-run walkthrough — inspect, plan, backup, verify, and restore on a normal Linux box.
---

# Guide

A first run on a normal Linux box: inspect → plan → backup → verify → restore.

Generic paths only — replace `/home/user` with your own home.

## 0. Preconditions

```bash
cd /path/to/linuxbkup
./linuxbkup deps status
```

If core tools are missing:

```bash
./linuxbkup deps install
```

## 1. Inspect

```bash
./linuxbkup inspect
```

Read-only. Shows distro, users, tool paths, and the **default archive destination** (usually `~/Backups/linuxbkup/<distro>-<timestamp>.tar.zst`).

## 2. Plan (no writes)

```bash
./linuxbkup plan
./linuxbkup plan -F          # full lists
./linuxbkup plan --json      # machine-readable
```

You should see what would be **included**, what is **skipped as regenerable**, and any **unexpected** paths.

Tip: plan is table-only by default; add `-v` for per-path sizes (slower on huge homes).

## 3. Backup

```bash
# interactive decisions for unexpected/large paths
./linuxbkup --ask backup

# non-interactive: safe defaults + auto-include unexpected
./linuxbkup -y backup

# explicit destination + keep the staging dir
./linuxbkup -y -k -o /home/user/Backups/linuxbkup/host.tar.zst backup
```

What happens:

1. Preflight (secrets policy, disk space)
2. Environment snapshot (tools + compat probes)
3. Capture package manifests (APT manuals, Node reinstall manifests)
4. Classify + copy home/config into staging (regenerables stripped)
5. Seal: secrets (`age` when enabled), INDEX, `checksums.sha256`
6. Pack **atomically**: `*.tar.zst.tmp` → verify → rename to final name
7. Summary + archive path

Stage / extract paths are always printed. Staging naming: `linuxbkup.<pid>.<rand>` under `${TMPDIR:-/tmp}` (or `-S/--stage-dir` parent).

## 4. Verify

```bash
./linuxbkup verify ~/Backups/linuxbkup/host.tar.zst
./linuxbkup verify /tmp/linuxbkup.<pid>.<rand>    # staging dir left after -k
```

Checksums are compared against `checksums.sha256`. Missing `schema.json` on an older archive is a **soft warning**, not a hard fail.

## 5. Restore

```bash
# same user, same machine
./linuxbkup -k -f restore ~/Backups/linuxbkup/host.tar.zst

# skip node_modules regeneration
./linuxbkup -k -f --skip-reinstall restore ~/Backups/linuxbkup/host.tar.zst

# non-interactive overwrite + reinstall all recorded Node projects
./linuxbkup -y -f restore ~/Backups/linuxbkup/host.tar.zst

# after PMs are installed — manifest + installs only
./linuxbkup -y --reinstall-only restore ~/Backups/linuxbkup/host.tar.zst

# sudo: home still targets SUDO_USER, not /root
sudo -E ./linuxbkup -k -f restore ~/Backups/linuxbkup/host.tar.zst
```

Rules:

- Existing files need **`-f`** (or `-a/--ask` in a TTY). `-y` alone will not overwrite.
- Secrets decrypt with `LINUXBKUP_SECRETS_PASS` / `_PASS_FILE` or a TTY prompt.
- Node reinstalls come from `packages/reinstalls.json` written at backup time. Failed projects are skipped, never abort the whole restore.
- Extract path is printed; kept when you pass `-k`.

## 6. Offsite (your job)

linuxbkup writes an archive. Copying it off the machine is on you:

```bash
rsync -av ~/Backups/linuxbkup/host.tar.zst user@otherhost:backups/
# or scp, rclone, a mounted drive, …
```

## Common tweaks

| Goal | Command |
|------|---------|
| Exclude a path pattern | `./linuxbkup -y -e '\.cache' backup` |
| Force-include something | `./linuxbkup -y -i '/home/user/extra' backup` |
| Ignore built-in rules | `./linuxbkup -y --no-defaults -i '...' backup` |
| Strict profile (skip large by default) | `./linuxbkup -y -p strict backup` |
| Cap staging size | `./linuxbkup -y -m 2G backup` |
| Parallel checksums | `./linuxbkup -y -w 8 backup` |

Next: [Secrets](./secrets.md) · [Platforms](./platforms.md) · [CLI](./cli.md)
