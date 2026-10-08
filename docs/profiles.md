# Profiles

Profiles tune how aggressively large or unexpected paths are included — without changing the safety model.

## The three

| Profile | Large-dir threshold | Large-file threshold | Suggested action for large under `--ask` |
|---------|---------------------|----------------------|------------------------------------------|
| `easy` | 2 GiB | 500 MiB | include |
| `balanced` *(default)* | 500 MiB | 100 MiB | include |
| `strict` | 100 MiB | 50 MiB | **skip** |

```bash
linuxbkup -p strict plan
linuxbkup -y -p strict backup
```

## How it interacts with modes

| Mode | Effect on large paths |
|------|------------------------|
| `--ask` / interactive TTY | Prompt; profile only sets the **suggested** answer |
| `-y` / non-TTY | Profile decides include vs skip for “large” paths (`strict` skips) |
| Default profile | `balanced` |

Unexpected paths are separate from “large”: they auto-include under `-y`/non-TTY regardless of profile; `--ask` prompts for them too.

## Related

- Cap staging size: `-m 2G` (abort, not suggestion)
- Reclaim regenerables: `-r` / `-R`
- Full CLI: [cli.md](./cli.md)
