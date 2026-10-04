# shellcheck shell=bash
# Default paths included in backup (relative to home unless absolute / {home}).

# Dotfiles / shell / git
CONSTRAINTS_BACKUP_DOTFILES=(
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
)

# Config / bin (directories — copied recursively with exclusions applied later)
CONSTRAINTS_BACKUP_DIRS=(
  .config
  .local/bin
  .ssh
  Projects
  projects
  src
  code
  Documents
  Workers
  Tools
)

# System-ish snippets we may copy if present (selective — not full /etc)
CONSTRAINTS_BACKUP_ETC=(
  /etc/wsl.conf
)
