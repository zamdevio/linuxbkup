# shellcheck shell=bash
# Fail-fast preflight gates (secrets, disk space) — before heavy rsync/pack.

# shellcheck source=lib/core/platform/fs_space.sh
source "${LINUXBKUP_ROOT}/lib/core/platform/fs_space.sh"
# shellcheck source=lib/fs/sizes.sh
source "${LINUXBKUP_ROOT}/lib/fs/sizes.sh"
# shellcheck source=lib/constraints/secrets.sh
source "${LINUXBKUP_ROOT}/lib/constraints/secrets.sh"

# True if home (or --mark-secret) likely stages secret paths.
backup_secrets_likely() {
  local home="${1:-${LINUXBKUP_HOME:-}}"
  local t expanded
  [[ -n "${home}" ]] || return 1
  if [[ "${#LINUXBKUP_MARK_SECRET[@]}" -gt 0 ]]; then
    return 0
  fi
  for t in "${CONSTRAINTS_SECRETS_TARGETS[@]+"${CONSTRAINTS_SECRETS_TARGETS[@]}"}"; do
    [[ -z "${t}" ]] && continue
    if declare -F constraints_expand_template >/dev/null 2>&1; then
      expanded="$(constraints_expand_template "${home}" "${t}")"
    else
      expanded="${home}/${t}"
    fi
    if [[ -e "${expanded}" ]]; then
      return 0
    fi
  done
  return 1
}

# Resolve secrets mode before any copy. Sets LINUXBKUP_SECRETS_MODE.
# Prompts on TTY when encryption needed; fatals under --yes without pass.
# Args: [home]
backup_secrets_preflight() {
  local home="${1:-${LINUXBKUP_HOME:-}}"
  local mode

  if [[ "${LINUXBKUP_NO_SECRETS:-0}" -eq 1 ]]; then
    LINUXBKUP_SECRETS_MODE="exclude"
    ui_kv "Secrets" "excluded (--no-secrets)"
    return 0
  fi
  if [[ "${LINUXBKUP_SECRETS_PLAIN:-0}" -eq 1 ]]; then
    LINUXBKUP_SECRETS_MODE="plain"
    ui_kv "Secrets" "plaintext (--secrets-plain)"
    return 0
  fi

  if [[ -n "${LINUXBKUP_SECRETS_PASS_FILE:-}" && -r "${LINUXBKUP_SECRETS_PASS_FILE}" ]]; then
    LINUXBKUP_SECRETS_PASS="$(<"${LINUXBKUP_SECRETS_PASS_FILE}")"
    export LINUXBKUP_SECRETS_PASS
  fi
  if [[ -n "${LINUXBKUP_SECRETS_PASS:-}" ]]; then
    LINUXBKUP_SECRETS_MODE="encrypt"
    ui_kv "Secrets" "will encrypt (passphrase ready)"
    return 0
  fi

  if ! backup_secrets_likely "${home}"; then
    LINUXBKUP_SECRETS_MODE="none"
    ui_kv "Secrets" "none detected"
    return 0
  fi

  # Secrets will be staged — must decide now (fail-fast).
  if [[ "${LINUXBKUP_DRY_RUN:-0}" -eq 1 ]]; then
    LINUXBKUP_SECRETS_MODE="encrypt"
    ui_kv "Secrets" "would encrypt (dry-run — set pass / --no-secrets / --secrets-plain for real run)"
    return 0
  fi

  if [[ "${LINUXBKUP_YES:-0}" -eq 1 ]]; then
    log_fatal "secrets will be staged: set LINUXBKUP_SECRETS_PASS or LINUXBKUP_SECRETS_PASS_FILE before backup, or pass --secrets-plain / --no-secrets (fail-fast — before copy)"
    return 1
  fi
  if [[ ! -t 0 && ! -c /dev/tty ]]; then
    log_fatal "non-TTY: secrets need LINUXBKUP_SECRETS_PASS(_FILE) or --secrets-plain / --no-secrets"
    return 1
  fi

  mode="$(backup_secrets_resolve_mode)" || return 1
  LINUXBKUP_SECRETS_MODE="${mode}"
  case "${mode}" in
    encrypt) ui_kv "Secrets" "will encrypt (passphrase set)" ;;
    plain) ui_kv "Secrets" "plaintext" ;;
    exclude) ui_kv "Secrets" "excluded" ;;
    *) ui_kv "Secrets" "${mode}" ;;
  esac
  return 0
}

# Disk space gate. Args: dest_path stage_parent [estimate_bytes]
# Fails if free space on stage or dest FS is below estimate (with 10% slack) or < 64MiB.
# When estimate is 0: floor-only check (quiet kv under current Preflight section).
backup_space_preflight() {
  local dest="$1" stage_parent="$2"
  local est="${3:-0}"
  local dest_avail stage_avail need slack dest_h stage_h need_h
  local floor=$((64 * 1024 * 1024))

  [[ -n "${dest}" && -n "${stage_parent}" ]] || return 0

  if ! dest_avail="$(platform_fs_avail_bytes "${dest}")"; then
    log_warn "could not read free space for destination: ${dest}"
    dest_avail=""
  fi
  if ! stage_avail="$(platform_fs_avail_bytes "${stage_parent}")"; then
    log_warn "could not read free space for stage parent: ${stage_parent}"
    stage_avail=""
  fi

  if [[ -n "${stage_avail}" && "${stage_avail}" -lt "${floor}" ]]; then
    log_fatal "stage filesystem has only $(fs_bytes_human "${stage_avail}") free (need ≥ 64MiB)"
    return 1
  fi
  if [[ -n "${dest_avail}" && "${dest_avail}" -lt "${floor}" ]]; then
    log_fatal "destination filesystem has only $(fs_bytes_human "${dest_avail}") free (need ≥ 64MiB)"
    return 1
  fi

  if [[ ! "${est}" =~ ^[0-9]+$ || "${est}" -le 0 ]]; then
    [[ -n "${dest_avail}" ]] && ui_kv "Dest free" "$(fs_bytes_human "${dest_avail}")"
    [[ -n "${stage_avail}" ]] && ui_kv "Stage free" "$(fs_bytes_human "${stage_avail}")"
    return 0
  fi

  ui_section "Space preflight"
  [[ -n "${dest_avail}" ]] && ui_kv "Dest free" "$(fs_bytes_human "${dest_avail}")"
  [[ -n "${stage_avail}" ]] && ui_kv "Stage free" "$(fs_bytes_human "${stage_avail}")"

  slack=$((est / 10))
  need=$((est + slack))
  need_h="$(fs_bytes_human "${need}")"
  ui_kv "Need (est+10%)" "${need_h}"
  if [[ -n "${stage_avail}" && "${stage_avail}" -lt "${need}" ]]; then
    log_fatal "stage FS free $(fs_bytes_human "${stage_avail}") < estimated need ${need_h}"
    return 1
  fi
  # Dest gets compressed archive — require at least ~25% of estimate free (rough)
  local dest_need=$((est / 4))
  if [[ -n "${dest_avail}" && "${dest_avail}" -lt "${dest_need}" ]]; then
    log_fatal "destination FS free $(fs_bytes_human "${dest_avail}") < ~25% of estimate ($(fs_bytes_human "${dest_need}"))"
    return 1
  fi
  printf '\n'
  return 0
}
