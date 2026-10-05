# shellcheck shell=bash
# Restore staged home/ + secrets/ + config/etc into a live tree.

# Count files under src that already exist at dest (same relative path).
restore_files_conflict_count() {
  local src="$1"
  local dest="$2"
  local n=0 rel f
  [[ -d "${src}" ]] || {
    printf '%s\n' "0"
    return 0
  }
  while IFS= read -r -d '' f; do
    rel="${f#"${src}"/}"
    [[ -z "${rel}" ]] && continue
    if [[ -e "${dest}/${rel}" ]]; then
      n=$((n + 1))
    fi
  done < <(find "${src}" -type f -print0 2>/dev/null || true)
  printf '%s\n' "${n}"
}

# Optional rsync --chown when running as root into a non-root home.
# Args: dest_user — empty = no chown
# Prints nothing or: --chown=user:group
restore_files_chown_args() {
  local dest_user="${1:-}"
  local group=""
  [[ -n "${dest_user}" ]] || return 0
  [[ "$(id -u)" -eq 0 ]] || return 0
  [[ "${dest_user}" == "root" ]] && return 0
  group="$(id -gn "${dest_user}" 2>/dev/null || true)"
  [[ -n "${group}" ]] || group="${dest_user}"
  printf '%s\n' "--chown=${dest_user}:${group}"
}

# Rsync one staged tree → dest. Gate overwrites with --force-overwrite.
# Args: src_dir dest_dir label [dest_user]
# Returns: 0 ok, 1 fail, 2 skipped (no src / dry-run reported)
restore_files_copy_tree() {
  local src="$1"
  local dest="$2"
  local label="$3"
  local dest_user="${4:-}"
  local conflicts=0 rc=0 action="" chown_arg=""
  local -a rargs=()

  if [[ ! -d "${src}" ]]; then
    log_verbose "no ${label} tree at ${src} — skip"
    return 2
  fi
  if [[ -z "$(find "${src}" -type f -print -quit 2>/dev/null || true)" ]]; then
    log_verbose "empty ${label} tree — skip"
    return 2
  fi

  conflicts="$(restore_files_conflict_count "${src}" "${dest}")"
  if [[ "${LINUXBKUP_DRY_RUN:-0}" -eq 1 ]]; then
    ui_kv "${label}" "would rsync → ${dest}/ (${conflicts} existing file(s))"
    return 2
  fi

  if [[ "${conflicts}" -gt 0 ]]; then
    if ! safety_require_force_overwrite "${label} (${conflicts} existing file(s) under ${dest})"; then
      return 1
    fi
  fi

  mkdir -p "${dest}"
  rargs=(-a)
  chown_arg="$(restore_files_chown_args "${dest_user}")"
  if [[ -n "${chown_arg}" ]]; then
    rargs+=("${chown_arg}")
    log_verbose "rsync ${chown_arg} for ${label}"
  fi
  rargs+=("${src}/" "${dest}/")

  linuxbkup_op_begin "restore-${label}" "${src}" 0 1
  while true; do
    set +e
    backup_rsync_run "${rargs[@]}"
    rc=$?
    set -e
    if [[ "${rc}" -eq 0 ]]; then
      linuxbkup_op_end
      log_ok "${label} → ${dest}/"
      return 0
    fi
    if backup_handle_interrupt "${rc}"; then
      action="${LINUXBKUP_INTERRUPT_RESULT}"
      case "${action}" in
        retry)
          log_info "retrying ${label} restore"
          continue
          ;;
        skip|continue)
          linuxbkup_interrupt_arm
          linuxbkup_op_end
          log_warn "skipped ${label} restore after interrupt"
          return 2
          ;;
        *)
          linuxbkup_interrupt_arm
          linuxbkup_op_end
          return 1
          ;;
      esac
    fi
    linuxbkup_op_end
    return 1
  done
}

# Restore home/, secrets/ (into home), and config/etc → /etc.
# Args: stage_root [dest_home] [dest_user]
# Returns: 0 ok (or soft-skips only), 1 hard fail
restore_files_apply() {
  local root="$1"
  local home="${2:-${LINUXBKUP_HOME:-${HOME:-}}}"
  local dest_user="${3:-}"
  local rc=0 any=0

  if [[ -z "${home}" ]]; then
    log_fatal "no destination home for restore"
    return 1
  fi

  # Guard: sudo(1) with SUDO_USER must never dump a user tree into /root
  if [[ "$(id -u)" -eq 0 && "${home}" == "/root" \
    && -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" \
    && "${LINUXBKUP_USER:-}" != "root" ]]; then
    log_fatal "refusing to restore home/secrets into /root under sudo"
    log_info "pass -u <username> (SUDO_USER=${SUDO_USER}). For root's own home: -u root"
    return 1
  fi

  if [[ -z "${dest_user}" ]]; then
    if declare -F env_resolve_user >/dev/null 2>&1; then
      dest_user="$(env_resolve_user)"
    else
      dest_user="$(id -un)"
    fi
  fi

  ui_kv_path "Restore home" "${home}"
  ui_kv "Restore as" "${dest_user}"

  # home/
  set +e
  restore_files_copy_tree "${root}/home" "${home}" "home" "${dest_user}"
  rc=$?
  set -e
  case "${rc}" in
    0) any=1 ;;
    2) ;;
    *) return 1 ;;
  esac

  # secrets/ → home (after decrypt left plaintext under root/secrets)
  if [[ -d "${root}/secrets" ]]; then
    set +e
    restore_files_copy_tree "${root}/secrets" "${home}" "secrets" "${dest_user}"
    rc=$?
    set -e
    case "${rc}" in
      0) any=1 ;;
      2) ;;
      *) return 1 ;;
    esac
  fi

  # config/etc → /etc (skip if not writable; tip includes sudo -u form)
  if [[ -d "${root}/config/etc" ]]; then
    if [[ "${LINUXBKUP_DRY_RUN:-0}" -eq 1 ]]; then
      restore_files_copy_tree "${root}/config/etc" "/etc" "config" ""
    elif [[ -w /etc ]] || [[ "$(id -u)" -eq 0 ]]; then
      set +e
      restore_files_copy_tree "${root}/config/etc" "/etc" "config" ""
      rc=$?
      set -e
      case "${rc}" in
        0) any=1 ;;
        2) ;;
        *) return 1 ;;
      esac
    else
      log_warn "config/etc present but /etc not writable — skip"
      ui_kv_path "Staged config" "${root}/config/etc"
      ui_item note "Re-run with sudo to apply /etc (home still targets SUDO_USER, not /root):"
      ui_item note "  sudo -E ./linuxbkup -u ${dest_user} -k -f restore <archive>"
    fi
  fi

  if [[ "${any}" -eq 0 && "${LINUXBKUP_DRY_RUN:-0}" -ne 1 ]]; then
    log_info "no home/secrets/config files applied"
  fi
  return 0
}
