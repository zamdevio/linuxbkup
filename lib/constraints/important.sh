# shellcheck shell=bash
# Potentially important user / application data path templates.
# Portable XDG / shell paths only — no host-shaped project dirnames (phase 02 scans the rest).

CONSTRAINTS_IMPORTANT_TARGETS=(
  .ssh
  .config
  .local/bin
  .local/share
  .local/state
  .gitconfig
)
