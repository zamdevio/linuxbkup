# shellcheck shell=bash
# Copy classified home/config paths into staging (full-home plan).

# shellcheck source=lib/classify/scan.sh
source "${LINUXBKUP_ROOT}/lib/classify/scan.sh"
# shellcheck source=lib/fs/sizes.sh
source "${LINUXBKUP_ROOT}/lib/fs/sizes.sh"

# Build effective backup path list from classification plan.
backup_home_paths() {
  local home="$1"
  classify_plan_include_paths "${home}"
}

# Turn one classify TSV row into a ranked include line (or nothing).
# Prints: bytes<TAB>human<TAB>class<TAB>path
backup_rank_row() {
  local path="$1" class="$2" action="$3" size="$4"
  local bytes=0 human mode

  case "${action}" in
    include) ;;
    ask)
      [[ "${LINUXBKUP_CLASSIFY_INCLUDE_ASK:-0}" -eq 1 ]] || return 0
      ;;
    *) return 0 ;;
  esac

  human="${size:-?}"
  if [[ "${LINUXBKUP_INSPECT_QUICK:-0}" -eq 1 ]]; then
    bytes=0
  elif [[ -n "${size}" && "${size}" != "?" ]]; then
    bytes="$(fs_parse_size_to_bytes "${size}" 2>/dev/null || printf '0')"
    human="${size}"
  else
    mode="filtered"
    constraints_is_regenerable_path "${path}" && mode="raw"
    if bytes="$(fs_du_bytes "${path}" "${mode}" 2>/dev/null)"; then
      human="$(fs_bytes_human "${bytes}")"
    else
      bytes=0
      human="?"
    fi
  fi
  [[ "${bytes}" =~ ^[0-9]+$ ]] || bytes=0
  printf '%s\t%s\t%s\t%s\n' "${bytes}" "${human}" "${class}" "${path}"
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
    --exclude 'go/pkg/'
    --exclude 'go/bin/'
    --exclude '.local/share/Trash/'
    --exclude '.yarn/cache/'
    --exclude '.pnpm-store/'
  )
}

# Base rsync args (+ regenerable excludes). Path-level progress is separate (stdout bar).
backup_rsync_args() {
  BACKUP_RSYNC_ARGS=(-a)
  BACKUP_RSYNC_ARGS+=("${BACKUP_RSYNC_EXCLUDES[@]+"${BACKUP_RSYNC_EXCLUDES[@]}"}")
}

# Abort if staging exceeds --max-size. Args: stage
backup_check_max_size() {
  local stage="$1"
  local used maxh usedh
  [[ -n "${LINUXBKUP_MAX_SIZE_BYTES:-}" && "${LINUXBKUP_MAX_SIZE_BYTES}" -gt 0 ]] || return 0
  [[ -d "${stage}" ]] || return 0

  used="$(fs_dir_bytes "${stage}")"
  if [[ "${used}" -gt "${LINUXBKUP_MAX_SIZE_BYTES}" ]]; then
    usedh="$(fs_bytes_human "${used}")"
    maxh="$(fs_bytes_human "${LINUXBKUP_MAX_SIZE_BYTES}")"
    term_progress_end
    log_fatal "staging ${usedh} exceeds --max-size ${maxh} (uncompressed stage footprint)"
    return 1
  fi
  return 0
}

backup_copy_home() {
  local home="$1" stage="$2"
  local path rel dest
  local -a paths=() unexpected_ask=() ranked=()
  local count=0 skipped=0
  local shown=0 limit
  local p class action size reason
  local i total bytes human est=0 esth maxh
  local row line

  # shellcheck source=lib/classify/plan.sh
  source "${LINUXBKUP_ROOT}/lib/classify/plan.sh"

  log_verbose "building include list from classification scan"
  log_debug "backup_copy_home home=${home} stage=${stage}"

  local -a scan_rows=()
  while IFS=$'\t' read -r p class action size reason; do
    [[ -z "${p:-}" ]] && continue
    log_debug "scan ${class}/${action} ${p}"
    scan_rows+=("$(printf '%s\t%s\t%s\t%s\t%s' "${p}" "${class}" "${action}" "${size}" "${reason}")")
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
      log_verbose "unexpected paths: include"
    else
      log_info "unexpected paths will be skipped"
      LINUXBKUP_CLASSIFY_INCLUDE_ASK=0
    fi
  fi

  local -a raw_ranked=()
  for row in "${scan_rows[@]+"${scan_rows[@]}"}"; do
    [[ -z "${row}" ]] && continue
    IFS=$'\t' read -r p class action size reason <<<"${row}" || true
    if line="$(backup_rank_row "${p}" "${class}" "${action}" "${size}")"; then
      [[ -n "${line}" ]] && raw_ranked+=("${line}")
    fi
  done
  if [[ "${#raw_ranked[@]}" -gt 0 ]]; then
    mapfile -t ranked < <(printf '%s\n' "${raw_ranked[@]}" | sort -t$'\t' -k1,1nr)
  fi
  paths=()
  for row in "${ranked[@]+"${ranked[@]}"}"; do
    [[ -z "${row}" ]] && continue
    IFS=$'\t' read -r bytes human class path <<<"${row}" || true
    paths+=("${path}")
    [[ "${bytes}" =~ ^[0-9]+$ ]] && est=$((est + bytes))
  done

  backup_plan_excludes
  backup_rsync_args
  log_verbose "include paths: ${#paths[@]} (ranked large→small)"

  ui_section "Paths to copy"
  if [[ "${#paths[@]}" -eq 0 ]]; then
    ui_item warn "no paths matched classification plan"
    return 0
  fi

  if [[ "${est}" -gt 0 ]]; then
    esth="$(fs_bytes_human "${est}")"
    ui_item note "estimated include size ~${esth} (filter-aware, largest first)"
  fi
  if [[ -n "${LINUXBKUP_MAX_SIZE_BYTES:-}" && "${LINUXBKUP_MAX_SIZE_BYTES}" -gt 0 ]]; then
    maxh="$(fs_bytes_human "${LINUXBKUP_MAX_SIZE_BYTES}")"
    ui_kv "Max stage" "${maxh}"
    if [[ "${est}" -gt 0 && "${est}" -gt "${LINUXBKUP_MAX_SIZE_BYTES}" ]]; then
      log_fatal "estimated include ~${esth} exceeds --max-size ${maxh}"
      return 1
    fi
  fi

  limit="$(constraints_list_limit)"
  for row in "${ranked[@]}"; do
    if [[ "${limit}" != "full" && "${shown}" -ge "${limit}" ]]; then
      break
    fi
    IFS=$'\t' read -r bytes human class path <<<"${row}" || true
    printf '  %8s  %-10s  %s\n' "${human}" "${class}" "$(term_path_link "${path}")"
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
  linuxbkup_tip_run plan
  printf '\n'

  if [[ "${LINUXBKUP_DRY_RUN:-0}" -eq 1 ]]; then
    log_info "dry-run — would rsync ${#paths[@]} paths into staging (largest first)"
    return 0
  fi

  if ! safety_confirm "Copy these paths into the backup staging area?" "y"; then
    log_skip "home/config copy cancelled"
    return 1
  fi

  total="${#paths[@]}"
  term_progress_set_stage "${stage}"
  term_progress_begin "${total}" "Copying into staging"
  # Ensure cursor restored if interrupted mid-loop
  trap 'term_progress_end; term_cursor_show; log_fatal "interrupted during copy"; exit 130' INT TERM

  i=0
  for path in "${paths[@]}"; do
    i=$((i + 1))
    term_progress_update "${i}" "${path}"

    if [[ ! -e "${path}" ]]; then
      skipped=$((skipped + 1))
      log_debug "missing path skipped: ${path}"
      continue
    fi

    if [[ "${path}" == /etc/* ]]; then
      dest="${stage}/config/etc/${path#/etc/}"
      mkdir -p "$(dirname "${dest}")"
      if [[ -d "${path}" ]]; then
        if ! backup_rsync_run "${BACKUP_RSYNC_ARGS[@]}" "${path}/" "${dest}/"; then
          term_progress_end
          return 1
        fi
      else
        if ! backup_rsync_run -a "${path}" "${dest}"; then
          term_progress_end
          return 1
        fi
      fi
      if ! backup_check_max_size "${stage}"; then
        return 1
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
    log_debug "rsync ${path} → ${dest}"
    if [[ -d "${path}" ]]; then
      mkdir -p "${dest}"
      if ! backup_rsync_run "${BACKUP_RSYNC_ARGS[@]}" "${path}/" "${dest}/"; then
        term_progress_end
        return 1
      fi
    else
      if ! backup_rsync_run -a "${path}" "${dest}"; then
        term_progress_end
        return 1
      fi
    fi
    if ! backup_check_max_size "${stage}"; then
      return 1
    fi
    count=$((count + 1))
  done

  term_progress_end
  trap 'log_fatal "interrupted during backup"; exit 130' INT TERM
  log_ok "copied ${count} paths (${skipped} skipped, ${LINUXBKUP_PERM_SKIPS:-0} soft-skips)"
  if [[ -d "${stage}" ]]; then
    ui_kv "Stage used" "$(fs_bytes_human "$(fs_dir_bytes "${stage}")")"
  fi
}
