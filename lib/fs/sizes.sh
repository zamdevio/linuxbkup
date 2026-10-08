# shellcheck shell=bash
# du-based size reporting. Honors filter stack (regenerable + user --exclude).
# Fast, shallow, best-effort — never abort inspect.

# Parse human size → bytes. Accepts bare ints or IEC suffixes (K/M/G/T, optional i/B).
# Prints integer bytes; returns 1 on bad input.
fs_parse_size_to_bytes() {
  local raw="${1:-}" norm
  [[ -n "${raw}" ]] || return 1
  [[ "${raw}" == "?" || "${raw}" == "-" ]] && { printf '0\n'; return 0; }

  norm="$(printf '%s' "${raw}" | tr '[:lower:]' '[:upper:]')"
  norm="${norm%B}"
  # 1.5Gi → 1.5G for numfmt --from=iec
  norm="${norm%I}"

  if [[ "${norm}" =~ ^[0-9]+$ ]]; then
    printf '%s\n' "${norm}"
    return 0
  fi

  if command -v numfmt >/dev/null 2>&1; then
    if numfmt --from=iec "${norm}" 2>/dev/null; then
      return 0
    fi
  fi

  # Minimal fallback: integer + single letter suffix
  if [[ "${norm}" =~ ^([0-9]+)([KMGT])$ ]]; then
    local n="${BASH_REMATCH[1]}" u="${BASH_REMATCH[2]}"
    case "${u}" in
      K) printf '%s\n' "$((n * 1024))" ;;
      M) printf '%s\n' "$((n * 1024 * 1024))" ;;
      G) printf '%s\n' "$((n * 1024 * 1024 * 1024))" ;;
      T) printf '%s\n' "$((n * 1024 * 1024 * 1024 * 1024))" ;;
    esac
    return 0
  fi
  return 1
}

# Bytes → short human (no trailing B when numfmt missing).
fs_bytes_human() {
  local bytes="${1:-0}"
  if declare -F compat_numfmt_human >/dev/null 2>&1; then
    compat_numfmt_human "${bytes}"
    return 0
  fi
  [[ "${bytes}" =~ ^[0-9]+$ ]] || bytes=0
  if command -v numfmt >/dev/null 2>&1; then
    numfmt --to=iec --suffix=B "${bytes}" 2>/dev/null || printf '%sB\n' "${bytes}"
  else
    printf '%sB\n' "${bytes}"
  fi
}

# Apparent size in bytes (filter-aware). Prints integer; returns 1 if unreadable.
# mode: filtered (default) | raw
fs_du_bytes() {
  local path="$1"
  local mode="${2:-filtered}"
  local out=""
  local -a excl=()
  [[ -e "${path}" ]] || return 1

  if [[ "${mode}" != "raw" ]] && ! constraints_is_regenerable_path "${path}"; then
    constraints_du_exclude_args excl
  fi

  if linuxbkup_require_cmd timeout; then
    out="$(timeout 8s du -sb "${excl[@]+"${excl[@]}"}" "${path}" 2>/dev/null || true)"
  else
    out="$(du -sb "${excl[@]+"${excl[@]}"}" "${path}" 2>/dev/null || true)"
  fi
  [[ -n "${out}" ]] || return 1
  awk '{print $1; exit}' <<<"${out}"
}

# Directory footprint in bytes (raw, no filter). Best-effort; 0 if missing.
fs_dir_bytes() {
  local path="$1" out
  [[ -d "${path}" ]] || { printf '0\n'; return 0; }
  out="$(du -sb "${path}" 2>/dev/null | awk '{print $1; exit}')" || true
  [[ "${out}" =~ ^[0-9]+$ ]] || out=0
  printf '%s\n' "${out}"
}

# Run du -sh; print "SIZE\tPATH".
# mode: filtered (default) | raw
# filtered = GNU du --exclude for regenerables + simple user excludes
# raw = full tree (use for intentional cache targets that are themselves regenerable)
fs_du_sh() {
  local path="$1"
  local mode="${2:-filtered}"
  local out=""
  local -a excl=()
  [[ -e "${path}" ]] || return 1

  if [[ "${mode}" != "raw" ]] && ! constraints_is_regenerable_path "${path}"; then
    constraints_du_exclude_args excl
  fi

  if linuxbkup_require_cmd timeout; then
    out="$(timeout 8s du -sh "${excl[@]+"${excl[@]}"}" "${path}" 2>/dev/null || true)"
  else
    out="$(du -sh "${excl[@]+"${excl[@]}"}" "${path}" 2>/dev/null || true)"
  fi
  [[ -n "${out}" ]] || return 1
  awk '{print $1 "\t" $2}' <<<"${out}"
}

fs_collect_size_targets() {
  local home="$1"
  constraints_build_paths "${home}" CONSTRAINTS_SIZE_TARGETS
  if [[ "${LINUXBKUP_VERBOSE:-0}" -eq 1 ]]; then
    constraints_build_paths "${home}" CONSTRAINTS_SIZE_TARGETS_VERBOSE
  fi
}

# Shallow drill-down: du --max-depth=1 with filter stack.
# Prints "HUMAN\tPATH" lines.
fs_home_large_dirs() {
  local home="$1"
  local min_kb="${2:-102400}" # ~100 MiB
  local limit top_n
  local kb path human
  local -a top_paths=()
  local -a excl=()

  [[ -d "${home}" ]] || return 0

  constraints_du_exclude_args excl

  limit="$(constraints_list_limit 8)"
  if [[ "${limit}" == "full" ]]; then
    top_n=50
  else
    top_n="${limit}"
  fi

  _fs_du_depth1_sorted() {
    local root="$1"
    if linuxbkup_require_cmd timeout; then
      timeout 20s du -xk --max-depth=1 "${excl[@]+"${excl[@]}"}" "${root}" 2>/dev/null || true
    else
      du -xk --max-depth=1 "${excl[@]+"${excl[@]}"}" "${root}" 2>/dev/null || true
    fi | awk -v min="${min_kb}" -v root="${root}" '$1 >= min && $2 != root {print}' | sort -nr
  }

  local _du_tmp
  _du_tmp="$(mktemp "${TMPDIR:-/tmp}/linuxbkup-du.XXXXXX")" || return 0
  _fs_du_depth1_sorted "${home}" >"${_du_tmp}" 2>/dev/null || true
  while read -r kb path; do
    [[ -z "${path:-}" ]] && continue
    if constraints_path_excluded "${path}"; then
      continue
    fi
    human="$(numfmt --to=iec --suffix=B "$((kb * 1024))" 2>/dev/null || printf '%sK' "${kb}")"
    printf '%s\t%s\n' "${human}" "${path}"
    top_paths+=("${path}")
    [[ "${#top_paths[@]}" -ge "${top_n}" ]] && break
  done <"${_du_tmp}"

  local child child_n=6
  [[ "${limit}" != "full" && "${top_n}" -lt 6 ]] && child_n="${top_n}"
  for child in "${top_paths[@]+"${top_paths[@]}"}"; do
    [[ -d "${child}" ]] || continue
    local n=0
    _fs_du_depth1_sorted "${child}" >"${_du_tmp}" 2>/dev/null || true
    while read -r kb path; do
      [[ -z "${path:-}" ]] && continue
      if constraints_path_excluded "${path}"; then
        continue
      fi
      human="$(numfmt --to=iec --suffix=B "$((kb * 1024))" 2>/dev/null || printf '%sK' "${kb}")"
      printf '%s\t%s\n' "${human}" "${path}"
      n=$((n + 1))
      [[ "${n}" -ge "${child_n}" ]] && break
    done <"${_du_tmp}"
  done
  rm -f "${_du_tmp}"
}

# Parallel du of independent paths. Fills named array with "HUMAN\tPATH" lines.
# Args: out_array_name path…   (uses worker policy op=du)
fs_du_paths_parallel() {
  local __out="$1"
  shift
  local -a paths=("$@")
  local n="${#paths[@]}"
  local workers i work p mode line size idx
  local -a bucket=()

  eval "${__out}=()"
  [[ "${n}" -gt 0 ]] || return 0

  # shellcheck source=lib/core/workers.sh
  source "${LINUXBKUP_ROOT}/lib/core/workers.sh"
  workers="$(linuxbkup_workers_for "${n}" du)"
  linuxbkup_workers_note du "${workers}" "${n} targets"

  if [[ "${workers}" -le 1 || "${n}" -le 1 ]]; then
    for p in "${paths[@]}"; do
      mode="filtered"
      constraints_is_regenerable_path "${p}" && mode="raw"
      if line="$(fs_du_sh "${p}" "${mode}")"; then
        size="${line%%$'\t'*}"
        eval "${__out}+=(\"\$(printf '%s\t%s' \"\${size}\" \"\${p}\")\")"
      fi
    done
    return 0
  fi

  work="$(mktemp -d "${TMPDIR:-/tmp}/linuxbkup-duw.XXXXXX")"
  for ((i = 0; i < workers; i++)); do
    : >"${work}/part.${i}"
  done
  i=0
  for p in "${paths[@]}"; do
    printf '%s\n' "${p}" >>"${work}/part.$((i % workers))"
    i=$((i + 1))
  done

  for ((i = 0; i < workers; i++)); do
    [[ -s "${work}/part.${i}" ]] || continue
    (
      idx=0
      while IFS= read -r p || [[ -n "${p}" ]]; do
        [[ -z "${p}" ]] && continue
        mode="filtered"
        constraints_is_regenerable_path "${p}" && mode="raw"
        if line="$(fs_du_sh "${p}" "${mode}")"; then
          size="${line%%$'\t'*}"
          printf '%s\t%s\n' "${size}" "${p}" >"${work}/r.${i}.${idx}"
          idx=$((idx + 1))
        fi
      done <"${work}/part.${i}"
    ) &
  done
  wait || true
  local _dusorted
  _dusorted="$(mktemp "${TMPDIR:-/tmp}/linuxbkup-du-sort.XXXXXX")" || { rm -rf "${work}"; return 0; }
  cat "${work}"/r.* 2>/dev/null | sort -t$'\t' -k2,2 >"${_dusorted}" || true
  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    IFS=$'\t' read -r size p <<<"${line}" || true
    [[ -n "${p:-}" ]] || continue
    eval "${__out}+=(\"\$(printf '%s\t%s' \"\${size}\" \"\${p}\")\")"
  done <"${_dusorted}"
  rm -f "${_dusorted}"
  rm -rf "${work}"
}

fs_print_filesystem() {
  local home="$1"
  local size path line
  local -a rows=() paths=() sized=()

  ui_section "Filesystem (selected targets)"
  ui_item note "sizes omit regenerable trees (node_modules, .venv, …) unless the target is itself a cache"

  if [[ "${LINUXBKUP_INSPECT_QUICK:-0}" -eq 1 ]]; then
    ui_item note "sizes skipped — LINUXBKUP_INSPECT_QUICK=1"
    local _tq
    _tq="$(mktemp "${TMPDIR:-/tmp}/linuxbkup-tq.XXXXXX")" || return 0
    fs_collect_size_targets "${home}" >"${_tq}" || true
    while IFS= read -r path; do
      [[ -z "${path}" ]] && continue
      rows+=("  ·  $(term_path_link "${path}")")
    done <"${_tq}"
    rm -f "${_tq}"
    printf '%s\n' "${rows[@]+"${rows[@]}"}" | constraints_list_apply
    constraints_list_footer "targets"
    printf '\n'
    ui_section "Large items under home"
    ui_item note "skipped — LINUXBKUP_INSPECT_QUICK=1"
    return 0
  fi

  local _tt _tl
  _tt="$(mktemp "${TMPDIR:-/tmp}/linuxbkup-tt.XXXXXX")" || return 0
  _tl="$(mktemp "${TMPDIR:-/tmp}/linuxbkup-tl.XXXXXX")" || { rm -f "${_tt}"; return 0; }
  fs_collect_size_targets "${home}" >"${_tt}" || true
  while IFS= read -r path; do
    [[ -z "${path}" ]] && continue
    paths+=("${path}")
  done <"${_tt}"
  rm -f "${_tt}"

  fs_du_paths_parallel sized "${paths[@]+"${paths[@]}"}"
  local line
  for line in "${sized[@]+"${sized[@]}"}"; do
    [[ -z "${line}" ]] && continue
    size="${line%%$'\t'*}"
    path="${line#*$'\t'}"
    rows+=("$(printf '  %6s  %s' "${size}" "$(term_path_link "${path}")")")
  done

  if [[ "${#rows[@]}" -eq 0 ]]; then
    ui_item note "none matched constraints (check --no-defaults / --include / --exclude)"
  else
    printf '%s\n' "${rows[@]}" | constraints_list_apply
    constraints_list_footer "targets"
  fi

  printf '\n'
  ui_section "Large items under home (≥ ~100MB, shallow, filter stack)"
  rows=()
  fs_home_large_dirs "${home}" >"${_tl}" || true
  while IFS=$'\t' read -r size path; do
    [[ -z "${path:-}" ]] && continue
    rows+=("$(printf '  %8s  %s' "${size}" "$(term_path_link "${path}")")")
  done <"${_tl}"
  rm -f "${_tl}"

  if [[ "${#rows[@]}" -eq 0 ]]; then
    ui_item note "none above threshold, or home unreadable"
  else
    printf '%s\n' "${rows[@]}" | constraints_list_apply
    constraints_list_footer "large items"
  fi
}
