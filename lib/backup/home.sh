# shellcheck shell=bash
# Copy allowlisted home/config paths into staging.

# shellcheck source=lib/constraints/backup_paths.sh
source "${WSLBKUP_ROOT}/lib/constraints/backup_paths.sh"

# Build effective backup path list for a home.
backup_home_paths() {
  local home="$1"
  local p
  CONSTRAINTS_BACKUP_ALL=("${CONSTRAINTS_BACKUP_DOTFILES[@]}" "${CONSTRAINTS_BACKUP_DIRS[@]}")
  constraints_build_paths "${home}" CONSTRAINTS_BACKUP_ALL

  for p in "${CONSTRAINTS_BACKUP_ETC[@]+"${CONSTRAINTS_BACKUP_ETC[@]}"}"; do
    [[ -e "${p}" ]] || continue
    if constraints_matches_any_regex "${p}" WSLBKUP_EXCLUDE_REGEXES; then
      continue
    fi
    printf '%s\n' "${p}"
  done
}

# Rsync excludes for regeneratable trees inside copied dirs.
backup_plan_excludes() {
  BACKUP_RSYNC_EXCLUDES=(
    --exclude 'node_modules/'
    --exclude '.venv/'
    --exclude 'venv/'
    --exclude '__pycache__/'
    --exclude 'target/'
    --exclude '.cache/'
    --exclude '.npm/'
    --exclude '.cargo/registry/'
    --exclude '.cargo/git/'
    --exclude '.rustup/'
    --exclude 'go/pkg/mod/'
    --exclude '.local/share/Trash/'
  )
}

backup_copy_home() {
  local home="$1" stage="$2"
  local path rel dest
  local -a paths=()
  local count=0 skipped=0
  local shown=0 limit

  mapfile -t paths < <(backup_home_paths "${home}")
  backup_plan_excludes

  ui_section "Home / config paths"
  if [[ "${#paths[@]}" -eq 0 ]]; then
    ui_item warn "no paths matched constraints"
    return 0
  fi

  limit="$(constraints_list_limit)"
  for path in "${paths[@]}"; do
    if [[ "${limit}" != "full" && "${shown}" -ge "${limit}" ]]; then
      break
    fi
    ui_item note "$(term_path_link "${path}")"
    shown=$((shown + 1))
  done
  if [[ "${#paths[@]}" -gt "${shown}" ]]; then
    log_info "Showing ${shown}/${#paths[@]} paths — pass -F/--full for all"
  fi
  printf '\n'
  ui_item note "Regeneratable trees (node_modules, .venv, caches, …) excluded via rsync"
  if [[ "${WSLBKUP_NO_SECRETS:-0}" -eq 1 ]]; then
    ui_item note "Secrets excluded (--no-secrets)"
  else
    ui_item note "Sensitive paths staged under secrets/ (encrypt in Phase 3)"
  fi
  printf '\n'

  if [[ "${WSLBKUP_DRY_RUN:-0}" -eq 1 ]]; then
    log_info "dry-run — would rsync ${#paths[@]} paths into staging"
    return 0
  fi

  if ! safety_confirm "Copy these paths into the backup staging area?" "y"; then
    log_skip "home/config copy cancelled"
    return 1
  fi

  for path in "${paths[@]}"; do
    if [[ ! -e "${path}" ]]; then
      skipped=$((skipped + 1))
      continue
    fi

    if [[ "${path}" == /etc/* ]]; then
      dest="${stage}/config/etc/${path#/etc/}"
      mkdir -p "$(dirname "${dest}")"
      if [[ -d "${path}" ]]; then
        rsync -a "${BACKUP_RSYNC_EXCLUDES[@]}" "${path}/" "${dest}/"
      else
        rsync -a "${path}" "${dest}"
      fi
      count=$((count + 1))
      continue
    fi

    case "${path}" in
      "${home}"/*)
        rel="${path#"${home}"/}"
        ;;
      *)
        log_warn "skip path outside home/etc: ${path}"
        skipped=$((skipped + 1))
        continue
        ;;
    esac

    if constraints_is_secret_path "${path}"; then
      if [[ "${WSLBKUP_NO_SECRETS:-0}" -eq 1 ]]; then
        log_skip "secrets excluded: ${path}"
        skipped=$((skipped + 1))
        continue
      fi
      dest="${stage}/secrets/${rel}"
    else
      dest="${stage}/home/${rel}"
    fi

    mkdir -p "$(dirname "${dest}")"
    if [[ -d "${path}" ]]; then
      mkdir -p "${dest}"
      rsync -a "${BACKUP_RSYNC_EXCLUDES[@]}" "${path}/" "${dest}/"
    else
      rsync -a "${path}" "${dest}"
    fi
    count=$((count + 1))
  done

  log_ok "copied ${count} paths (${skipped} skipped)"
}
