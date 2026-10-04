# shellcheck shell=bash
# Paths / EREs treated as potentially regeneratable.
#
# These names are *recognition signals* for strip/skip (du/rsync/classify) —
# not a substitute for profile/ask decisions on top-level unexpected paths.
# Prefer size + flags + ask for “should we back this up?”; use this list so
# known caches inside included trees (Projects/, .local/share/, …) are not dumped.
#
# Keep in sync with common language/framework ignore conventions. Per-directory
# .gitignore is also honored at rsync time (unless --no-gitignore).

# Concrete path templates (expanded under home / absolute)
CONSTRAINTS_REGENERABLE_TARGETS=(
  .cache
  .npm
  .cargo/registry
  .cargo/git
  .rustup
  .local/share/pipx
  .local/share/pnpm
  .local/share/Trash
  .local/share/uv
  .local/share/mise
  .local/share/flatpak
  .local/share/containers
  .bun/install/cache
  go
  go/pkg
  go/bin
  go/pkg/mod
  /var/cache/apt
)

# Regex patterns (ERE) for matching discovered paths
CONSTRAINTS_REGENERABLE_REGEXES=(
  '/node_modules(/|$)'
  '/\.next(/|$)'
  '/\.nuxt(/|$)'
  '/\.output(/|$)'
  '/\.turbo(/|$)'
  '/\.vercel(/|$)'
  '/\.svelte-kit(/|$)'
  '/\.angular(/|$)'
  '/\.vite(/|$)'
  '/\.parcel-cache(/|$)'
  '/\.sass-cache(/|$)'
  '/\.eslintcache(/|$)'
  '/\.stylelintcache(/|$)'
  '/\.ruff_cache(/|$)'
  '/\.nox(/|$)'
  '/\.venv(/|$)'
  '/venv(/|$)'
  '/__pycache__(/|$)'
  '/__pypackages__(/|$)'
  '/\.eggs(/|$)'
  '/\.tox(/|$)'
  '/\.mypy_cache(/|$)'
  '/\.pytest_cache(/|$)'
  '/\.ipynb_checkpoints(/|$)'
  '/\.ruff_cache(/|$)'
  '/htmlcov(/|$)'
  '/\.nyc_output(/|$)'
  '/\.coverage(/|$)'
  '/target(/|$)'
  '/dist(/|$)'
  '/build(/|$)'
  '/out(/|$)'
  '/coverage(/|$)'
  '/bower_components(/|$)'
  '/\.cache(/|$)'
  '/\.npm(/|$)'
  '/\.pnpm-store(/|$)'
  '/\.local/share/pnpm(/|$)'
  '/\.yarn/cache(/|$)'
  '/\.yarn/unplugged(/|$)'
  '/\.bun/install/cache(/|$)'
  '/\.cargo/registry(/|$)'
  '/\.cargo/git(/|$)'
  '/\.rustup(/|$)'
  '/go/pkg(/|$)'
  '/go/bin(/|$)'
  '/go/pkg/mod(/|$)'
  '/\.local/share/pipx(/|$)'
  '/\.local/share/Trash(/|$)'
  '/\.local/share/uv(/|$)'
  '/\.local/share/mise(/|$)'
  '/var/cache/apt(/|$)'
  '/\.gradle(/|$)'
  '/\.m2/repository(/|$)'
  '/vendor/bundle(/|$)'
  '/\.bundle(/|$)'
  '/\.dart_tool(/|$)'
  '/\.pub-cache(/|$)'
  '/\.terraform(/|$)'
  '/\.terragrunt-cache(/|$)'
  '/\.stack-work(/|$)'
  '/_build(/|$)'
  '/\.elixir_ls(/|$)'
  '/Pods(/|$)'
  '/DerivedData(/|$)'
  '/\.cxx(/|$)'
  '/cmake-build-(debug|release)(/|$)'
  '/\.idea(/|$)'
  '/\.vs(/|$)'
  '/\.jekyll-cache(/|$)'
  '/_site(/|$)'
)

# Basename / path-component globs for GNU du --exclude= and rsync --exclude
# (keep in sync with regenerable intent; used by filter stack)
# Prefer directory basenames that are almost never "source of truth".
CONSTRAINTS_DU_EXCLUDE_GLOBS=(
  node_modules
  .next
  .nuxt
  .output
  .turbo
  .vercel
  .svelte-kit
  .angular
  .vite
  .parcel-cache
  .sass-cache
  .eslintcache
  .stylelintcache
  .ruff_cache
  .nox
  .venv
  venv
  __pycache__
  __pypackages__
  .eggs
  .tox
  .mypy_cache
  .pytest_cache
  .ipynb_checkpoints
  htmlcov
  .nyc_output
  target
  dist
  build
  out
  coverage
  bower_components
  .cache
  .npm
  .pnpm-store
  .dart_tool
  .pub-cache
  .terraform
  .terragrunt-cache
  .stack-work
  _build
  .elixir_ls
  Pods
  DerivedData
  .cxx
  .gradle
  .m2
  vendor
  Trash
  .jekyll-cache
  _site
  # Store basenames under ~/.local/share (and rare package dirs)
  pnpm
  .rustup
)
