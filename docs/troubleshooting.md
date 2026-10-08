# Troubleshooting

Short failures → what to check. Run with `-v` (and `-d` for forensic stderr) when you need more detail.

## `deps` says tools are missing

```bash
./linuxbkup deps status
./linuxbkup deps install
./linuxbkup deps howto zstd
```

Bootstrap detects apk / apt / pacman / Termux pkg / dnf / yum / brew. On Alpine/iSH/Termux, install `zstd` first if anything else fails early.

## Backup dry-run or plan feels slow

Classification walks the home directory. On very large trees this is expected cost, not a hang. Use:

- `plan` without `-v` (sizes skipped by default)
- `-e` / built-in regenerable strips to shrink the universe
- `-m/--max-size` to abort staging if it grows too large

## `compat: tar|zstd pipe failed`

`tar` or `zstd` missing, or a broken install. Re-run `./linuxbkup deps status` and reinstall those packages. The context banner prints the probed tar impl (`gnu` / `busybox` / `bsd`).

## Checksum mismatch on verify

1. Re-run `./linuxbkup verify <archive>` — confirm the failure is stable
2. Ensure you are not verifying a **partial** `.tmp` file from an interrupted pack
3. Payload mismatch = archive is untrustworthy — restore from another copy
4. Only `metadata/events.jsonl` drift is soft-warned (telemetry)

## Restore refuses to overwrite

By design:

```text
Refusing to overwrite … Pass -f/--force-overwrite, or -a/--ask in a TTY.
```

`-y` is not enough. Use `-f` when you mean it, or `-a` to confirm per tree.

## Secrets: `--yes backup with secrets requires …`

Provide a passphrase via env/`_PASS_FILE`, or pass `--no-secrets` / `--secrets-plain`. See [Secrets](./secrets.md).

## Restore targets the wrong home under sudo

linuxbkup prefers `SUDO_USER` (the human), not `/root`. Override with `-u <user>`; use `-u root` only when restoring root’s own home.

## Ctrl+C / Ctrl+Z

- **Ctrl+C:** stop children → menu on the real tty → `r` retry · `s` skip · `c` continue · `q` quit · `x` quit+cleanup staging
- **Ctrl+Z:** suspend the whole job (`fg` / `bg`). Works on backup and restore paths (extract / rsync / reinstalls). On minimal shells job control can still be quirky — prefer Ctrl+C for a clean stop
- Mid-reinstall **`q`** soft-quits the **batch** only; restore continues to the summary

## Node reinstalls skipped

Common reasons (each logs a reason):

- PM not installed on the target (install node/pnpm/yarn, then `--reinstall-only`)
- Windows/interop PM shims (`/mnt/c/...`) ignored on purpose
- Workspace sources missing on disk — “run a full restore first”
- Project failed — listed in the end report; re-run failed-only when prompted

## rsync metadata mode warning

Destination filesystem does not support chmod/symlinks (FAT/exFAT/NTFS/9p). Files copy; modes/symlinks may not. Stage on a native Linux path when you can.

## Stage/extract path missing from output

Paths are printed for `backup -k`, `restore` (always for archives), and `verify` (archives). If you redirected stdout, check stderr / `-v` logs. `-k` keeps the directory after success.

## Still stuck

```bash
./linuxbkup --help
./linuxbkup help <command>
./linuxbkup inspect
./tests/smoke.sh
```

Include: distro (`cat /etc/os-release`), `./linuxbkup deps status`, the exact command, and `-d` output snippet (redact secrets).

Next: [CLI](./cli.md) · [Platforms](./platforms.md)
