# shellcheck shell=bash
# Copy classified home/config paths into staging (full-home plan).

# shellcheck source=lib/classify/scan.sh
source "${LINUXBKUP_ROOT}/lib/classify/scan.sh"

# Build effective backup path list from classification plan.
backup_home_paths() {
  local home="$1"
  classify_plan_include_paths "${home}"
}

# Rsync excludes for regeneratable trees — driven by CONSTRAINTS_DU_EXCLUDE_GLOBS.
backup_plan_excludes() {
  local g
  BACKUP_RSYNC_EXCLUDES=()
  for g in "${CONSTRAINTS_DU_EXCLUDE_GLOBS[@]+"${CONSTRAINTS_DU_EXCLUDE_GLOBS[@]}"}"; do
    [[ -z "${g}" ]] && continue
    BACKUP_RSYNC_EXCLUDES+=(--exclude "${g}/")
  done
  BACKUP_RSYNC_EXCLUDES+=(
    --exclude '.cargo/registry/'
    --exclude '.cargo/git/'
    --exclude 'go/pkg/mod/'
    --exclude '.local/share/Trash/'
    --exclude '.yarn/cache/'
    --exclude '.pnpm-store/'
  )
}

backup_copy_home() {
  local home="$1" stage="$2"
  local path rel dest
  local -a paths=() unexpected_ask=()
  local count=0 skipped=0
  local shown=0 limit
  local p class action size reason

  # shellcheck source=lib/fs/sizes.sh
  source "${LINUXBKUP_ROOT}/lib/fs/sizes.sh"
  # shellcheck source=lib/classify/plan.sh
  source "${LINUXBKUP_ROOT}/lib/classify/plan.sh"

  # Sizes are informational; skip du unless -v
  if [[ "${LINUXBKUP_VERBOSE:-0}" -ne 1 ]]; then
    LINUXBKUP_INSPECT_QUICK=1
  fi

  classify_print_plan "${home}"
  printf '\n'

  if [[ "${LINUXBKUP_PRINT_PLAN:-0}" -eq 1 ]]; then
    log_ok "print-plan only — no copy"
    return 0
  fi

  # Collect ask-class unexpected for interactive confirm
  while IFS=$'\t' read -r p class action size reason; do
    [[ -z "${p:-}" ]] && continue
    if [[ "${class}" == "unexpected" && "${action}" == "ask" ]]; then
      unexpected_ask+=("${p}")
    fi
  done < <(classify_scan_home "${home}")

  if [[ "${#unexpected_ask[@]}" -gt 0 ]]; then
    ui_section "Unexpected paths (decide)"
    for path in "${unexpected_ask[@]}"; do
      ui_item note "$(term_path_link "${path}")"
    done
    printf '\n'
    if safety_confirm "Include these unexpected paths in the backup?" "y"; then
      LINUXBKUP_CLASSIFY_INCLUDE_ASK=1
      export LINUXBKUP_CLASSIFY_INCLUDE_ASK
    else
      log_info "unexpected paths will be skipped"
      LINUXBKUP_CLASSIFY_INCLUDE_ASK=0
    fi
  fi

  mapfile -t paths < <(backup_home_paths "${home}")
  backup_plan_excludes

  ui_section "Paths to copy"
  if [[ "${#paths[@]}" -eq 0 ]]; then
    ui_item warn "no paths matched classification plan"
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
  if [[ "${LINUXBKUP_NO_SECRETS:-0}" -eq 1 ]]; then
    ui_item note "Secrets excluded (--no-secrets)"
  else
    ui_item note "Sensitive paths staged under secrets/ (encrypt in a later phase)"
  fi
  printf '\n'

  if [[ "${LINUXBKUP_DRY_RUN:-0}" -eq 1 ]]; then
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
      if [[ "${LINUXBKUP_NO_SECRETS:-0}" -eq 1 ]]; then
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
