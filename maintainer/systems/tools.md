# System — tools + guides

| Path | Role |
|------|------|
| `lib/tools/check.sh` | Presence checks + How-To + install runner; `tools_pkg_family` (pkg/apk/apt/dnf/yum/pacman/brew); `tools_resolve` falls back to any sha256 provider |
| `lib/tools/compat.sh` | Lean op-usable probes (tar\|zstd pipe, rsync -a, sha via compat layer) |
| `lib/core/compat/compat.sh` | **Compat layer (phase 13)** — tar/sha/rsync/numfmt probes + wrappers |
| `lib/tools/catalog.sh` | Core/optional dep lists + `tools_install_command` (incl. Termux `pkg`) |
| `lib/cmd/deps.sh` | `linuxbkup deps status\|install\|howto`; **one-command bootstrap** (D2) |
| `lib/core/context.sh` | Per-command banner (context + tools + compat capability matrix) |
| `lib/core/workers.sh` | `-w/--workers` cap + per-op scaling (checksum/du/verify/pack) |
| `guides/tools/<cmd>.guide` | Install metadata per tool |

Commands call `cmd_context_begin` with `--required` / `--optional` tools before work. Missing required tools print a platform-specific How-To from the matching `.guide` and exit. Required tools that need a pipe/flags also get a **compat** probe (cached per process) — presence ≠ usable.

`sha256sum` as a *required* name is satisfied by **any** provider: `sha256sum` | `shasum -a 256` | `openssl dgst` (`compat_sha_tool`).

```bash
./linuxbkup deps
./linuxbkup deps install
./linuxbkup -y deps install age
./linuxbkup deps howto fzf
./linuxbkup -w 4 backup   # worker cap for checksums / du batches / zstd -T
```

## Tool expectations (shipped — phase 13)

| Tool | Behavior |
|------|----------|
| `tar` | Impl probe (`compat_tar_type`); pack/extract/list via wrappers; GNU `--warning` only when supported |
| `zstd` | Required; clearer install path via guides; compress/test probes |
| `sha256sum` | Fallback chain: sha256sum → shasum -a 256 → openssl dgst |
| `rsync` | Feature probe; non-Linux dest → metadata-manifest mode (no chmod/symlink hard-fail) |
| `numfmt` | Optional; `compat_numfmt_human` pure-bash IEC fallback |
| `age` | Optional for secrets — unchanged |
| `fzf` | Optional picker — non-interactive fallback already required |

## deps bootstrap (shipped — phase 13 D2)

`deps install` with **2+ missing tools** builds a **one-command** install from the detected PM:

| Family | Command shape |
|--------|----------------|
| Termux `pkg` | `pkg install -y <pkgs>` |
| Alpine `apk` | `sudo apk add <pkgs>` |
| Debian/Ubuntu `apt` | `sudo apt update && sudo apt install -y <pkgs>` |
| `pacman` | `sudo pacman -S --needed --noconfirm <pkgs>` |
| dnf/yum/brew | analogous |

**Non-interactive by default:** `deps install` does **not** prompt per tool — invoking the `deps` subcommand is itself the consent (`LINUXBKUP_DEPS_INTERACTIVE=0`). Pass `--interactive` to opt back into a per-tool confirm (ad-hoc `tools_install_one` adheres to this flag). TTY: confirm before running. `-y` / non-TTY: documented non-interactive path (`LINUXBKUP_YES=1`). Dry-run prints the command only. Fallback: per-tool `tools_install_one`.

Optional later: `fzf` for ask UI (shipped phase 03) — never required.
