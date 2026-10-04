# shellcheck shell=bash
# APT / dpkg manifest capture.

apt_available() {
  linuxbkup_require_cmd apt-mark && linuxbkup_require_cmd dpkg
}

# Write package manifests into staging/packages/
apt_capture_manifests() {
  local stage="$1"
  local pkg_dir="${stage}/packages"

  if ! apt_available; then
    log_skip "apt/dpkg not available — skipping package manifests"
    return 0
  fi

  if [[ "${LINUXBKUP_DRY_RUN:-0}" -eq 1 ]]; then
    log_info "dry-run — would capture apt-mark showmanual + dpkg -l"
    return 0
  fi

  mkdir -p "${pkg_dir}"

  apt-mark showmanual 2>/dev/null | sort >"${pkg_dir}/apt.manual" || true
  dpkg-query -W -f='${Package}\t${Version}\t${Status}\n' 2>/dev/null \
    | sort >"${pkg_dir}/dpkg.state" || true

  if [[ -d /etc/apt/sources.list.d ]]; then
    mkdir -p "${pkg_dir}/apt-sources"
    # Copy list files only (no keyrings with secrets beyond public keys — still careful)
    find /etc/apt/sources.list.d -maxdepth 1 -type f \( -name '*.list' -o -name '*.sources' \) \
      -exec cp -a {} "${pkg_dir}/apt-sources/" \; 2>/dev/null || true
  fi
  if [[ -f /etc/apt/sources.list ]]; then
    cp -a /etc/apt/sources.list "${pkg_dir}/apt-sources.list" 2>/dev/null || true
  fi

  local n
  n="$(wc -l <"${pkg_dir}/apt.manual" | tr -d ' ')"
  log_ok "APT manual packages recorded: ${n}"
  ui_kv_path "apt.manual" "${pkg_dir}/apt.manual"
}
