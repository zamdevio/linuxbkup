# CLI reference

```bash
linuxbkup --help
linuxbkup help inspect
linuxbkup version
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
linuxbkup deps
linuxbkup deps install          # missing core
linuxbkup deps install all      # core + optional, skip present
linuxbkup deps howto zstd
```

Install guides: `guides/tools/<name>.guide`.

## Path filters

```bash
linuxbkup inspect --exclude '\.cache' -T 5
linuxbkup inspect --no-defaults --include Projects
```

Built-in lists live in `lib/constraints/`.
