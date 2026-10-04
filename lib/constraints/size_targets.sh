# shellcheck shell=bash
# Default filesystem size-scan targets (relative to home unless absolute / {home}).

CONSTRAINTS_SIZE_TARGETS=(
  .cache
  .local
  .local/share
  .config
  .npm
  .cargo
  .rustup
  go
  .nvm
  /var
  /var/lib/docker
  /var/cache/apt
)

# Extra targets only shown with --verbose
CONSTRAINTS_SIZE_TARGETS_VERBOSE=(
  /usr
)
