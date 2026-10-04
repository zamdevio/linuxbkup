# CLI reference

```bash
wslbkup --help
wslbkup help inspect
wslbkup version
```

## Commands

| Command | Purpose |
|---------|---------|
| `inspect` | Read-only environment scan |
| `backup` | Create archive (Phase 2+) |
| `restore` | Reconstruct from archive (Phase 4+) |
| `verify` | Integrity check |
| `list` | High-level archive listing |
| `deps` | Tool status / install / How-To |

## Dependencies

```bash
wslbkup deps
wslbkup deps install          # missing core
wslbkup deps install all      # core + optional, skip present
wslbkup deps howto zstd
```

Install guides: `guides/tools/<name>.guide`.

## Path filters

```bash
wslbkup inspect --exclude '\.cache' -T 5
wslbkup inspect --no-defaults --include Projects
```

Built-in lists live in `lib/constraints/`.
