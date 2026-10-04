# System — CLI

Surface: root `wslbkup` bin.

- Parses global flags in `lib/core/common.sh`
- Logging: `lib/core/logging.sh`
- Safety gates: `lib/core/safety.sh`
- Dispatches to `lib/cmd/<name>.sh`

Commands: `inspect`, `backup`, `restore`, `verify`, `list`.
