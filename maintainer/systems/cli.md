# System — CLI

Surface: root `wslbkup` bin.

- Parses global flags in `lib/core/common.sh`
- Terminal UI: `lib/core/terminal/style.sh` (+ `links.sh`, `control.sh`)
- Safety gates: `lib/core/safety.sh`
- Dispatches to `lib/cmd/<name>.sh`

Commands: `inspect`, `backup`, `restore`, `verify`, `list`, `deps`.
