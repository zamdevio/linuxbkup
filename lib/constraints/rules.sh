# shellcheck shell=bash
# Portable classification *rules* (basenames / classes) — not host-shaped path lists.

# Top-level (or relative) basenames that are known includes when present.
CONSTRAINTS_RULE_INCLUDE_FILES=(
  .bashrc
  .bash_profile
  .profile
  .zshrc
  .zprofile
  .gitconfig
  .gitignore_global
  .vimrc
  .tmux.conf
  .inputrc
  .npmrc
  .netrc
)

# Top-level directories that are known includes (copied with regenerable strips).
CONSTRAINTS_RULE_INCLUDE_DIRS=(
  .config
  .ssh
  .gnupg
  .aws
)

# Children of ~/.local that are known includes (never "skip all of .local").
CONSTRAINTS_RULE_LOCAL_INCLUDE=(
  bin
  share
  state
)

# Top-level basenames that are skip/regenerable by default (reclaim later).
CONSTRAINTS_RULE_SKIP_BASENAMES=(
  .cache
  .npm
  .npm-global
  .cargo
  .rustup
  .bun
  .gradle
  .m2
  .tox
  .pytest_cache
  .mypy_cache
  .local/share/Trash
  snap
  .Trash
)

# Optional system snippets (absolute) when present.
CONSTRAINTS_RULE_ETC=(
  /etc/wsl.conf
)
