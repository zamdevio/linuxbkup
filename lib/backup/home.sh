# shellcheck shell=bash
# Copy classified home/config paths into staging (full-home plan).

# shellcheck source=lib/classify/scan.sh
source "${LINUXBKUP_ROOT}/lib/classify/scan.sh"
# shellcheck source=lib/fs/sizes.sh
source "${LINUXBKUP_ROOT}/lib/fs/sizes.sh"
# shellcheck source=lib/core/profile.sh
source "${LINUXBKUP_ROOT}/lib/core/profile.sh"
# shellcheck source=lib/ask/select.sh
source "${LINUXBKUP_ROOT}/lib/ask/select.sh"
# shellcheck source=lib/backup/reclaim.sh
source "${LINUXBKUP_ROOT}/lib/backup/reclaim.sh"
# shellcheck source=lib/backup/secrets_crypt.sh
source "${LINUXBKUP_ROOT}/lib/backup/secrets_crypt.sh"

# Paths reclaimed from regenerable skips (full rsync, no strip excludes).
declare -A BACKUP_RECLAIMED=()
declare -A BACKUP_MARKED_SECRET=()

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
    # Match directory at any depth (node_modules, .next, pnpm, …)
    BACKUP_RSYNC_EXCLUDES+=(--exclude "${g}/" --exclude "${g}")
  done
  for g in "${CONSTRAINTS_FILE_EXCLUDE_GLOBS[@]+"${CONSTRAINTS_FILE_EXCLUDE_GLOBS[@]}"}"; do
    [[ -z "${g}" ]] && continue
    BACKUP_RSYNC_EXCLUDES+=(--exclude "${g}")
  done
  # Path-shaped regenerables (keep .cargo/config.toml; strip stores/caches only)
  BACKUP_RSYNC_EXCLUDES+=(
    --exclude '.cargo/registry/'
    --exclude '.cargo/git/'
    --exclude '.rustup/'
    --exclude 'go/pkg/mod/'
    --exclude 'go/pkg/'
    --exclude 'go/bin/'
    --exclude '.local/share/Trash/'
    --exclude '.local/share/pnpm/'
    --exclude '.local/share/uv/'
    --exclude '.local/share/mise/'
    --exclude '.local/share/pipx/'
    --exclude '.local/share/NuGet/'
    --exclude '.local/share/JetBrains/'
    --exclude '.local/lib/'
    --exclude '.yarn/cache/'
    --exclude '.yarn/unplugged/'
    --exclude '.pnpm-store/'
    --exclude '.bun/install/cache/'
    --exclude '.nuget/packages/'
    --exclude '.composer/cache/'
    --exclude '.cursor-server/'
    --exclude '.vscode-server/'
    --exclude '.vscode-remote/'
    --exclude '.net/'
  )
}

# Base rsync args (+ regenerable excludes + per-dir .gitignore merge).
backup_rsync_args() {
  BACKUP_RSYNC_ARGS=(-a)
  BACKUP_RSYNC_ARGS+=("${BACKUP_RSYNC_EXCLUDES[@]+"${BACKUP_RSYNC_EXCLUDES[@]}"}")
  # Honor .gitignore in every directory unless --no-gitignore
  if [[ "${LINUXBKUP_NO_GITIGNORE:-0}" -ne 1 ]]; then
    # dir-merge: apply each directory's .gitignore as exclude rules while walking
    BACKUP_RSYNC_ARGS+=(--filter=':- .gitignore')
  fi
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

# Path → bytes cache for one backup_copy_home run (avoid double du).
declare -A BACKUP_SIZE_CACHE=()

# Resolve human/bytes for a path. Byte-accurate filtered du when possible
# (never sum rounded du -sh labels — that under-counted stage by ~15%).
# Cached per path within a backup run.
backup_resolve_size() {
  local path="$1" size="${2:-}"
  local bytes=0 human mode
  if [[ "${LINUXBKUP_INSPECT_QUICK:-0}" -eq 1 ]]; then
    printf '0\t?\n'
    return 0
  fi
  if [[ -n "${BACKUP_SIZE_CACHE[${path}]+x}" ]]; then
    bytes="${BACKUP_SIZE_CACHE[${path}]}"
    human="$(fs_bytes_human "${bytes}")"
    printf '%s\t%s\n' "${bytes}" "${human}"
    return 0
  fi
  # Prefer integer bytes from classify TSV (already filter-aware du -sb)
  if [[ "${size}" =~ ^[0-9]+$ ]]; then
    bytes="${size}"
    human="$(fs_bytes_human "${bytes}")"
    BACKUP_SIZE_CACHE["${path}"]="${bytes}"
    printf '%s\t%s\n' "${bytes}" "${human}"
    return 0
  fi
  mode="filtered"
  constraints_is_regenerable_path "${path}" && mode="raw"
  if bytes="$(fs_du_bytes "${path}" "${mode}" 2>/dev/null)"; then
    [[ "${bytes}" =~ ^[0-9]+$ ]] || bytes=0
    human="$(fs_bytes_human "${bytes}")"
  else
    bytes="$(fs_parse_size_to_bytes "${size}" 2>/dev/null || printf '0')"
    [[ "${bytes}" =~ ^[0-9]+$ ]] || bytes=0
    human="${size:-?}"
    [[ "${human}" == "?" && "${bytes}" -gt 0 ]] && human="$(fs_bytes_human "${bytes}")"
  fi
  BACKUP_SIZE_CACHE["${path}"]="${bytes}"
  printf '%s\t%s\n' "${bytes}" "${human}"
}

backup_copy_home() {
  local home="$1" stage="$2"
  local path rel dest
  local -a paths=() ranked=() decide_rows=() ask_picked=()
  local count=0 skipped=0
  local shown=0 limit
  local p class action size reason
  local i total bytes human est=0 esth maxh used usedh delta pct
  local row line suggested need_ask=0
  local is_unexp is_lg display_class
  local -A include_set=()
  BACKUP_ESTIMATE_BYTES=0
  BACKUP_SIZE_CACHE=()

  # shellcheck source=lib/classify/plan.sh
  source "${LINUXBKUP_ROOT}/lib/classify/plan.sh"

  log_verbose "building include list from classification scan"
  log_debug "backup_copy_home home=${home} stage=${stage} profile=${LINUXBKUP_PROFILE:-balanced} ask=${LINUXBKUP_ASK:-0}"

  local -a scan_rows=()
  while IFS=$'\t' read -r p class action size reason; do
    [[ -z "${p:-}" ]] && continue
    log_debug "scan ${class}/${action} ${p}"
    scan_rows+=("$(printf '%s\t%s\t%s\t%s\t%s' "${p}" "${class}" "${action}" "${size}" "${reason}")")
  done < <(classify_scan_home "${home}")

  # Build decide set + default includes (profile + --ask / --yes rules).
  for row in "${scan_rows[@]+"${scan_rows[@]}"}"; do
    [[ -z "${row}" ]] && continue
    IFS=$'\t' read -r p class action size reason <<<"${row}" || true
    case "${action}" in
      include|ask) ;;
      *) continue ;;
    esac
    IFS=$'\t' read -r bytes human <<<"$(backup_resolve_size "${p}" "${size}")" || true

    is_unexp=0
    is_lg=0
    display_class="${class}"
    [[ "${class}" == "unexpected" ]] && is_unexp=1
    if profile_is_large "${p}" "${bytes}"; then
      is_lg=1
      display_class="${class}+large"
    fi
    suggested="include"
    if [[ "${is_unexp}" -eq 1 || "${is_lg}" -eq 1 ]]; then
      suggested="$(profile_suggest_large)"
    fi

    if [[ "${LINUXBKUP_ASK:-0}" -eq 1 ]]; then
      if [[ "${is_unexp}" -eq 1 || "${is_lg}" -eq 1 ]]; then
        decide_rows+=("$(printf '%s\t%s\t%s\t%s' "${p}" "${human}" "${display_class}" "${suggested}")")
        need_ask=1
      else
        include_set["${p}"]=1
      fi
      continue
    fi

    if [[ "${LINUXBKUP_YES:-0}" -eq 1 ]]; then
      [[ "${action}" == "ask" ]] && continue
      if [[ "${is_lg}" -eq 1 ]] && ! profile_yes_include_large; then
        log_verbose "profile ${LINUXBKUP_PROFILE}: skip large ${p} (${human})"
        continue
      fi
      include_set["${p}"]=1
      continue
    fi

    # TTY without --ask/--yes: prompt unexpected (action=ask); keep other includes
    if [[ "${action}" == "ask" ]]; then
      decide_rows+=("$(printf '%s\t%s\t%s\t%s' "${p}" "${human}" "${display_class}" "${suggested}")")
      need_ask=1
      continue
    fi
    include_set["${p}"]=1
  done

  if [[ "${need_ask}" -eq 1 && "${#decide_rows[@]}" -gt 0 ]]; then
    if ! ask_select_backup_paths decide_rows ask_picked \
      "Large / unexpected items  (profile: ${LINUXBKUP_PROFILE:-balanced})"; then
      return 1
    fi
    for path in "${ask_picked[@]+"${ask_picked[@]}"}"; do
      include_set["${path}"]=1
    done
    LINUXBKUP_CLASSIFY_INCLUDE_ASK=1
    export LINUXBKUP_CLASSIFY_INCLUDE_ASK
  fi

  BACKUP_RECLAIMED=()
  if ! backup_apply_reclaim scan_rows include_set; then
    return 1
  fi

  # --mark-secret: force path into include + secrets staging
  BACKUP_MARKED_SECRET=()
  local ms expanded
  for ms in "${LINUXBKUP_MARK_SECRET[@]+"${LINUXBKUP_MARK_SECRET[@]}"}"; do
    [[ -z "${ms}" ]] && continue
    expanded="$(constraints_normalize_user_path "${ms}")"
    [[ -e "${expanded}" ]] || {
      log_warn "mark-secret path missing: ${expanded}"
      continue
    }
    include_set["${expanded}"]=1
    BACKUP_MARKED_SECRET["${expanded}"]=1
  done

  local -a raw_ranked=()
  for row in "${scan_rows[@]+"${scan_rows[@]}"}"; do
    [[ -z "${row}" ]] && continue
    IFS=$'\t' read -r p class action size reason <<<"${row}" || true
    [[ -n "${include_set[${p}]+x}" ]] || continue
    IFS=$'\t' read -r bytes human <<<"$(backup_resolve_size "${p}" "${size}")" || true
    raw_ranked+=("$(printf '%s\t%s\t%s\t%s' "${bytes}" "${human}" "${class}" "${p}")")
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

  BACKUP_ESTIMATE_BYTES="${est}"
  if [[ "${est}" -gt 0 ]]; then
    esth="$(fs_bytes_human "${est}")"
    ui_item note "estimated include size ${esth} (byte-accurate, filter-aware, largest first)"
  fi
  if [[ -n "${LINUXBKUP_MAX_SIZE_BYTES:-}" && "${LINUXBKUP_MAX_SIZE_BYTES}" -gt 0 ]]; then
    maxh="$(fs_bytes_human "${LINUXBKUP_MAX_SIZE_BYTES}")"
    ui_kv "Max stage" "${maxh}"
    if [[ "${est}" -gt 0 && "${est}" -gt "${LINUXBKUP_MAX_SIZE_BYTES}" ]]; then
      log_fatal "estimated include ${esth} exceeds --max-size ${maxh}"
      return 1
    fi
  fi

  # Space gate with real estimate (stage parent + dest) before confirm/copy
  if [[ "${LINUXBKUP_DRY_RUN:-0}" -ne 1 ]] && declare -F backup_space_preflight >/dev/null 2>&1; then
    local stage_parent dest_for_space
    stage_parent="$(dirname "${stage}")"
    [[ -n "${LINUXBKUP_STAGE_DIR:-}" ]] && stage_parent="${LINUXBKUP_STAGE_DIR}"
    dest_for_space="${LINUXBKUP_OUTPUT:-${dest:-${stage}}}"
    if [[ -n "${LINUXBKUP_BACKUP_DEST:-}" ]]; then
      dest_for_space="${LINUXBKUP_BACKUP_DEST}"
    fi
    if ! backup_space_preflight "${dest_for_space}" "${stage_parent}" "${est}"; then
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
  ui_item note "Regenerables stripped (node_modules, .next, caches, build/dist, …)"
  if [[ "${LINUXBKUP_NO_GITIGNORE:-0}" -eq 1 ]]; then
    ui_item note "Per-directory .gitignore ignored (--no-gitignore)"
  else
    ui_item note "Per-directory .gitignore honored (pass --no-gitignore to bypass)"
  fi
  if [[ "${LINUXBKUP_NO_SECRETS:-0}" -eq 1 ]]; then
    ui_item note "Secrets excluded (--no-secrets)"
  elif [[ "${LINUXBKUP_SECRETS_PLAIN:-0}" -eq 1 ]]; then
    ui_item note "Secrets staged plaintext (--secrets-plain)"
  else
    ui_item note "Sensitive paths staged under secrets/ then age-encrypted"
  fi
  if [[ "${#BACKUP_RECLAIMED[@]}" -gt 0 ]]; then
    ui_item note "Reclaimed regenerables: ${#BACKUP_RECLAIMED[@]}"
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
  for row in "${ranked[@]}"; do
    IFS=$'\t' read -r bytes human class path <<<"${row}" || true
    [[ -z "${path}" ]] && continue
    i=$((i + 1))
    term_progress_update "${i}" "${path}" "${human}"

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

    if constraints_is_secret_path "${path}" || [[ -n "${BACKUP_MARKED_SECRET[${path}]+x}" ]]; then
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
      if [[ -n "${BACKUP_RECLAIMED[${path}]+x}" ]]; then
        # Full tree for reclaimed regenerables (no strip excludes)
        if ! backup_rsync_run -a "${path}/" "${dest}/"; then
          term_progress_end
          return 1
        fi
      elif ! backup_rsync_run "${BACKUP_RSYNC_ARGS[@]}" "${path}/" "${dest}/"; then
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
    used="$(fs_dir_bytes "${stage}")"
    usedh="$(fs_bytes_human "${used}")"
    ui_kv "Stage used" "${usedh}"
    if [[ "${BACKUP_ESTIMATE_BYTES:-0}" -gt 0 && "${used}" =~ ^[0-9]+$ ]]; then
      esth="$(fs_bytes_human "${BACKUP_ESTIMATE_BYTES}")"
      ui_kv "Estimate was" "${esth}"
      if [[ "${used}" -gt "${BACKUP_ESTIMATE_BYTES}" ]]; then
        delta=$((used - BACKUP_ESTIMATE_BYTES))
      else
        delta=$((BACKUP_ESTIMATE_BYTES - used))
      fi
      pct=$((delta * 100 / BACKUP_ESTIMATE_BYTES))
      # metadata/packages/secrets layout can add a little; warn only on real drift
      if [[ "${pct}" -ge 5 && "${delta}" -ge $((50 * 1024 * 1024)) ]]; then
        log_warn "stage vs estimate differs by $(fs_bytes_human "${delta}") (~${pct}%) — check filters / regenerables"
      fi
    fi
  fi
}
