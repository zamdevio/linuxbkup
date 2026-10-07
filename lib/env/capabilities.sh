# shellcheck shell=bash
# Capability probes — presence only. Never fail inspect if one tool is absent.
# Broad catalog so one tool covers common Linux stacks (no fork-to-add-nginx).

_cap_line() {
  local label="$1"
  shift
  if linuxbkup_require_cmd "$@"; then
    ui_item ok "${label}"
    return 0
  fi
  ui_item off "${label}"
  return 1
}

# True if any of the commands exist.
_cap_any() {
  local c
  for c in "$@"; do
    linuxbkup_require_cmd "${c}" && return 0
  done
  return 1
}

_cap_line_any() {
  local label="$1"
  shift
  if _cap_any "$@"; then
    ui_item ok "${label}"
    return 0
  fi
  ui_item off "${label}"
  return 1
}

env_print_package_managers() {
  ui_section "Package managers"
  _cap_line apt apt || true
  _cap_line dpkg dpkg || true
  _cap_line dnf dnf || true
  _cap_line yum yum || true
  _cap_line pacman pacman || true
  _cap_line apk apk || true
  _cap_line zypper zypper || true
  _cap_line flatpak flatpak || true
  _cap_line snap snap || true
  _cap_line brew brew || true
  _cap_line nix nix || true
  _cap_line nix-env nix-env || true
  _cap_line guix guix || true
  _cap_line emerge emerge || true
  _cap_line xbps-install xbps-install || true
  _cap_line swupd swupd || true
  _cap_line eopkg eopkg || true
}

env_print_language_tooling() {
  ui_section "Language / package tooling"
  _cap_line pip pip || true
  _cap_line pip3 pip3 || true
  _cap_line pipx pipx || true
  _cap_line npm npm || true
  _cap_line pnpm pnpm || true
  _cap_line yarn yarn || true
  _cap_line bun bun || true
  _cap_line cargo cargo || true
  _cap_line go go || true
  _cap_line gem gem || true
  _cap_line bundle bundle || true
  _cap_line composer composer || true
  _cap_line poetry poetry || true
  _cap_line uv uv || true
}

env_print_tool_managers() {
  ui_section "Tool version managers"
  _cap_line mise mise || true
  _cap_line asdf asdf || true
  _cap_line nvm nvm || true
  _cap_line fnm fnm || true
  _cap_line n n || true
  _cap_line pyenv pyenv || true
  _cap_line rbenv rbenv || true
  _cap_line sdkman sdk || true
  _cap_line volta volta || true
  _cap_line proto proto || true
}

env_print_services() {
  ui_section "Services & process managers"
  if linuxbkup_require_cmd systemctl; then
    if systemctl is-system-running >/dev/null 2>&1 \
      || systemctl list-units --type=service >/dev/null 2>&1; then
      ui_item ok "systemd"
    else
      ui_item warn "systemd (binary present; may be inactive)"
    fi
  else
    ui_item off "systemd"
  fi

  _cap_line pm2 pm2 || true
  _cap_line supervisorctl supervisorctl || true
  _cap_line supervisord supervisord || true
  _cap_line forever forever || true
  _cap_line_any "ssh" ssh sshd || true
  if [[ -x /usr/sbin/sshd ]] && ! linuxbkup_require_cmd sshd; then
    ui_item ok "sshd (/usr/sbin/sshd)"
  fi
}

env_print_web_servers() {
  ui_section "Web servers / proxies"
  _cap_line nginx nginx || true
  _cap_line_any "apache" apache2 httpd apachectl || true
  _cap_line caddy caddy || true
  _cap_line traefik traefik || true
  _cap_line haproxy haproxy || true
}

env_print_databases() {
  ui_section "Databases"
  _cap_line_any "postgresql" psql postgres || true
  _cap_line_any "mysql/mariadb" mysql mariadb || true
  _cap_line redis-cli redis-cli || true
  _cap_line mongosh mongosh || true
  _cap_line mongo mongo || true
  _cap_line sqlite3 sqlite3 || true
  _cap_line_any "clickhouse" clickhouse clickhouse-client || true
}

env_print_containers_cloud() {
  ui_section "Containers & cloud CLIs"
  _cap_line docker docker || true
  _cap_line podman podman || true
  _cap_line nerdctl nerdctl || true
  _cap_line kubectl kubectl || true
  _cap_line helm helm || true
  _cap_line aws aws || true
  _cap_line gcloud gcloud || true
  _cap_line az az || true
  _cap_line doctl doctl || true
  _cap_line flyctl flyctl || true
  _cap_line wrangler wrangler || true
  _cap_line terraform terraform || true
  _cap_line pulumi pulumi || true
}

env_print_dev_environments() {
  ui_section "Development environments"
  if linuxbkup_require_cmd python3 || linuxbkup_require_cmd python; then
    ui_item ok "Python"
  else
    ui_item off "Python"
  fi
  _cap_line Node.js node || true
  _cap_line Rust rustc || true
  _cap_line Go go || true
  _cap_line Ruby ruby || true
  _cap_line_any "Java" java javac || true
  _cap_line_any "PHP" php php8.3 php8.2 || true
  _cap_line_any ".NET" dotnet || true
}

env_print_backup_tools() {
  ui_section "Backup tooling"
  _cap_line rsync rsync || true
  _cap_line tar tar || true
  _cap_line zstd zstd || true
  if declare -F compat_sha_tool >/dev/null 2>&1; then
    _cap_line "Checksum" "$(compat_sha_tool)" || true
  else
    _cap_line sha256sum sha256sum || true
  fi
  _cap_line age age || true
  _cap_line du du || true
  _cap_line find find || true
}
