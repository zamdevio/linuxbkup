# shellcheck shell=bash
# Default paths included in backup (relative to home unless absolute / {home}).
# Portable only — no host-shaped project dirnames. Extra trees: --include (phase 02: full HOME scan).

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

# Config / bin / keys (directories — copied recursively with exclusions applied later)
CONSTRAINTS_BACKUP_DIRS=(
  .config
  .local/bin
  .ssh
)

# Optional system snippets when present (selective — not full /etc)
CONSTRAINTS_BACKUP_ETC=(
  /etc/wsl.conf
)
