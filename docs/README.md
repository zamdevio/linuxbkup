# Docs — linuxbkup

End-user documentation for the Bash-first Linux backup/restore CLI.

**Site:** [linuxbkup.pages.dev](https://linuxbkup.pages.dev) (VitePress; content is this folder).
**VitePress home:** [`index.md`](./index.md) · **This file:** GitHub folder index only.

Works on most Linux distros — **desktop, VPS, and WSL**. Alpine / iSH / Termux are best-effort via the compat layer and `linuxbkup deps`.

## Start here

| Doc | Read this when |
|-----|----------------|
| [Install](./install.md) | Getting the binary on a machine |
| [Concepts](./concepts.md) | What gets backed up, what is skipped, how safety works |
| [Guide](./guide.md) | First full run: plan → backup → verify → restore |
| [Platforms](./platforms.md) | Host matrix, package managers, external mounts |
| [Schema](./schema.md) | Archive layout, `schema.json`, checksums |
| [Secrets](./secrets.md) | `age` encryption, passphrase, `--yes` rules |
| [Troubleshooting](./troubleshooting.md) | When something fails |
| [CLI reference](./cli.md) | Every command and global flag |

## Thirty-second version

```bash
./linuxbkup deps
./linuxbkup plan
./linuxbkup -y backup
./linuxbkup verify ~/Backups/linuxbkup/<archive>.tar.zst
./linuxbkup -k -f restore ~/Backups/linuxbkup/<archive>.tar.zst
```

No Node, no Python, no daemon. One Bash binary plus tools you already have (`tar`, `zstd`, `rsync`, `du`, `find`, optional `age`).

## Principles

1. **Back up what cannot be reliably regenerated.** Config, dotfiles, selected data — not whole disks, not `/usr`.
2. **Safety by default.** Overwrite needs `-f`. `--yes` never silently skips secrets.
3. **Portable archives.** Atomic `tar.zst` + checksums; restore on another distro.
4. **Honest hosts.** GNU Linux is the happy path; other hosts get explicit compat behavior, not silent breakage.

Generic paths only in examples: `/home/user`, `~/Backups/linuxbkup/archive.tar.zst`.
