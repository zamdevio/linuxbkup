# System — tools + guides

| Path | Role |
|------|------|
| `lib/tools/check.sh` | Presence checks + How-To + install runner |
| `lib/tools/catalog.sh` | Core/optional dep lists |
| `lib/cmd/deps.sh` | `wslbkup deps status|install|howto` |
| `lib/core/context.sh` | Per-command banner (context + tools) |
| `guides/tools/<cmd>.guide` | Install metadata per tool |

Commands call `cmd_context_begin` with `--required` / `--optional` tools before work. Missing required tools print a platform-specific How-To from the matching `.guide` and exit.

```bash
wslbkup deps
wslbkup deps install
wslbkup -y deps install age
wslbkup deps howto zstd
```
