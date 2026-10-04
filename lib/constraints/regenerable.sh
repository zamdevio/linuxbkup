# shellcheck shell=bash
# Paths / EREs treated as potentially regeneratable.

# Concrete path templates (expanded under home / absolute)
CONSTRAINTS_REGENERABLE_TARGETS=(
  .cache
  .npm
  .cargo/registry
  .cargo/git
  .rustup
  .local/share/pipx
  go/pkg/mod
  /var/cache/apt
)

# Regex patterns (ERE) for matching discovered paths
CONSTRAINTS_REGENERABLE_REGEXES=(
  '/node_modules(/|$)'
  '/\.venv(/|$)'
  '/venv(/|$)'
  '/__pycache__(/|$)'
  '/target(/|$)'
  '/\.cache(/|$)'
  '/\.npm(/|$)'
  '/\.pnpm-store(/|$)'
  '/\.yarn/cache(/|$)'
  '/\.cargo/registry(/|$)'
  '/\.cargo/git(/|$)'
  '/\.rustup(/|$)'
  '/go/pkg/mod(/|$)'
  '/\.local/share/pipx(/|$)'
  '/\.local/share/Trash(/|$)'
  '/var/cache/apt(/|$)'
  '/\.pytest_cache(/|$)'
  '/\.mypy_cache(/|$)'
  '/\.tox(/|$)'
  '/\.gradle(/|$)'
  '/\.m2/repository(/|$)'
  '/vendor/bundle(/|$)'
)
