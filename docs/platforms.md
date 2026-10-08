# Platforms

One binary. Same commands. Different hosts, different tool reality.

## Matrix

| Host | Status | What to expect |
|------|--------|----------------|
| GNU Linux desktop | Happy path | Everything works as documented |
| VPS / server (Debian, Ubuntu, Fedora, Arch, …) | Happy path | Same; watch disk space for staging + archive |
| WSL | Happy path | Default archive may land in Windows Downloads when a mount resolves; Linux-native tools still required |
| Alpine / BusyBox | Best-effort | `tar` may be BusyBox — flag fallbacks; install `zstd`; sha may be `shasum`/`openssl` |
| iSH (iOS) | Best-effort | Minimal rootfs; run `deps` first; job-control (Ctrl+Z) can be flaky |
| Termux | Best-effort | Non-FHS prefix; `pkg` bootstrap; no hardcoded `/usr/bin` assumptions |
| FAT / exFAT / NTFS / 9p mounts as dest | Supported via metadata mode | rsync will not hard-fail on chmod/symlink; modes may not round-trip |

Run this on any host before the first backup:

```bash
./linuxbkup deps status
./linuxbkup deps install
```

`deps` detects the package family and can print/run a **one-command** bootstrap.

## Package managers

| Family | Detection | Bootstrap shape |
|--------|-----------|-----------------|
| Termux `pkg` | `TERMUX_VERSION` + `pkg` | `pkg install -y <pkgs>` |
| Alpine `apk` | `apk` without apt | `sudo apk add <pkgs>` |
| Debian/Ubuntu `apt` | `apt` / `apt-get` | `sudo apt update && sudo apt install -y <pkgs>` |
| Arch `pacman` | `pacman` | `sudo pacman -S --needed <pkgs>` |
| Fedora `dnf` / `yum` | dnf / yum | `sudo dnf install -y <pkgs>` |
| Homebrew | `brew` | `brew install <pkgs>` |

`-y` / non-TTY: bootstrap runs without an extra prompt (still only the tools you asked for). TTY: confirm first.

## Tool compatibility

| Tool | Requirement | Fallback |
|------|-------------|----------|
| `tar` | Required | Probed: GNU / BusyBox / BSD. GNU `--warning` omitted when unsupported |
| `zstd` | Required | Install via `deps` / distro package |
| `rsync` | Required | Metadata mode on non-Linux filesystems |
| `sha256sum` | Required **as a capability** | `shasum -a 256` or `openssl dgst` |
| `du`, `find` | Required | — |
| `age` | Optional | Secrets subset only |
| `numfmt` | Optional | Pure-bash human sizes |
| `fzf` | Optional | Non-interactive fallback always exists |

## WSL notes

- Install Linux tools **inside** the Linux distro (`sudo apt install tar zstd rsync coreutils`), not via Windows interop shims.
- `linuxbkup` ignores Windows/interop binaries (`/mnt/c/...`, `*.exe`) when resolving tools and PMs.
- Default destination preference: Windows Downloads when a mount looks available, else `~/Backups/linuxbkup/`.

## External / non-Linux mounts

If the **staging parent** or **restore destination** is FAT/exFAT/NTFS/9p-style:

- Backup staging still works on the Linux side when possible.
- Restore rsync switches to **metadata mode**: recursive + times, no chmod/symlink hard-fail. A log line tells you metadata mode is on.
- Symlinks and exact modes may not survive — expected on those filesystems.

Prefer staging under `${TMPDIR:-/tmp}` or a native ext4/btrfs path, and only write the **final archive** to the external mount.

## Soak checklist

Hardware-specific validation (pack/extract/verify, Ctrl+Z resume, metadata-mode restore, deps bootstrap) is recorded during host soak runs. Until a host is soaked, treat iSH/Termux/Alpine results as best-effort and run `linuxbkup deps` first.

Next: [CLI](./cli.md) · [Troubleshooting](./troubleshooting.md)
