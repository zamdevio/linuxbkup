# System — tools + guides

| Path | Role |
|------|------|
| `lib/tools/check.sh` | Presence checks + How-To + install runner |
| `lib/tools/catalog.sh` | Core/optional dep lists |
| `lib/cmd/deps.sh` | `linuxbkup deps status\|install\|howto` |
| `lib/core/context.sh` | Per-command banner (context + tools) |
| `guides/tools/<cmd>.guide` | Install metadata per tool |

Commands call `cmd_context_begin` with `--required` / `--optional` tools before work. Missing required tools print a platform-specific How-To from the matching `.guide` and exit.

```bash
./linuxbkup deps
./linuxbkup deps install
./linuxbkup -y deps install age
./linuxbkup deps howto zstd
```

Optional later: `fzf` for ask UI ([phase 03](../phases/03-profiles-ask-flags.md)) — never required.
