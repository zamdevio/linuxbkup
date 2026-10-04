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

# Basename / path-component globs for GNU du --exclude= and rsync --exclude
# (keep in sync with regenerable intent; used by filter stack)
CONSTRAINTS_DU_EXCLUDE_GLOBS=(
  node_modules
  .venv
  venv
  __pycache__
  target
  .cache
  .npm
  .pnpm-store
  .yarn
  .cargo
  .rustup
  .pytest_cache
  .mypy_cache
  .tox
  .gradle
  .m2
  vendor
  Trash
  pipx
)
