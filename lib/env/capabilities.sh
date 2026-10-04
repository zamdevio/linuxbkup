# shellcheck shell=bash
# Capability probes — never fail the whole inspect if one tool is absent.

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

env_print_package_managers() {
  ui_section "Package managers"
  _cap_line apt apt || true
  _cap_line dpkg dpkg || true
  _cap_line pip pip || true
  _cap_line pip3 pip3 || true
  _cap_line pipx pipx || true
  _cap_line npm npm || true
  _cap_line pnpm pnpm || true
  _cap_line yarn yarn || true
  _cap_line cargo cargo || true
  _cap_line go go || true
  _cap_line gem gem || true
  _cap_line bundle bundle || true
}

env_print_services() {
  ui_section "Services"
  if linuxbkup_require_cmd systemctl; then
    if systemctl is-system-running >/dev/null 2>&1 \
      || systemctl list-units --type=service >/dev/null 2>&1; then
      ui_item ok "systemd"
    else
      ui_item warn "systemd (binary present; may be inactive in this WSL)"
    fi
  else
    ui_item off "systemd"
  fi

  if linuxbkup_require_cmd sshd || [[ -x /usr/sbin/sshd ]]; then
    ui_item ok "ssh (sshd present)"
  elif linuxbkup_require_cmd ssh; then
    ui_item warn "ssh (client only)"
  else
    ui_item off "ssh"
  fi

  if linuxbkup_require_cmd docker; then
    ui_item ok "docker"
  else
    ui_item off "docker"
  fi
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
}

env_print_backup_tools() {
  ui_section "Backup tooling"
  _cap_line rsync rsync || true
  _cap_line tar tar || true
  _cap_line zstd zstd || true
  _cap_line sha256sum sha256sum || true
  _cap_line age age || true
  _cap_line du du || true
}
