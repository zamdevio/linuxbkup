# System — tools + guides

| Path | Role |
|------|------|
| `lib/tools/check.sh` | Presence checks + How-To + install runner |
| `lib/tools/compat.sh` | Lean op-usable probes (tar\|zstd pipe, rsync -a, sha256sum) |
| `lib/tools/catalog.sh` | Core/optional dep lists |
| `lib/cmd/deps.sh` | `linuxbkup deps status\|install\|howto` |
| `lib/core/context.sh` | Per-command banner (context + tools + compat) |
| `lib/core/workers.sh` | `-w/--workers` cap + per-op scaling (checksum/du/verify/pack) |
| `guides/tools/<cmd>.guide` | Install metadata per tool |

Commands call `cmd_context_begin` with `--required` / `--optional` tools before work. Missing required tools print a platform-specific How-To from the matching `.guide` and exit. Required tools that need a pipe/flags also get a **compat** probe (cached per process) — presence ≠ usable.

```bash
./linuxbkup deps
./linuxbkup deps install
./linuxbkup -y deps install age
./linuxbkup deps howto zstd
./linuxbkup -w 4 backup   # worker cap for checksums / du batches / zstd -T
```

## Tool expectations (today vs phase 13)

| Tool | Today | Phase 13 target |
|------|--------|-----------------|
| `tar` | GNU flags in pack/extract (`--warning`, etc.) | Impl probe + BusyBox/BSD flag sets |
| `zstd` | Required; missing → fail | Same + clearer iSH/Termux install path |
| `sha256sum` | Required | Fallback: `shasum -a 256` / openssl |
| `rsync` | `-a` + filter stack; chmod/symlink on non-Linux dest can fail | Feature probe + metadata-manifest mode |
| `numfmt` | Optional; bash fallback strings | Keep optional |
| `age` | Optional for secrets | Unchanged |
| `fzf` | Optional picker | Non-interactive fallback already required |

Optional later: `fzf` for ask UI (shipped phase 03) — never required. Bootstrap install via apk/apt/pacman is **phase 13 D2**, not implemented.
