# shellcheck shell=bash
# du-based size reporting. Honors filter stack (regenerable + user --exclude).
# Fast, shallow, best-effort — never abort inspect.

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

  while read -r kb path; do
    [[ -z "${path:-}" ]] && continue
    if constraints_path_excluded "${path}"; then
      continue
    fi
    human="$(numfmt --to=iec --suffix=B "$((kb * 1024))" 2>/dev/null || printf '%sK' "${kb}")"
    printf '%s\t%s\n' "${human}" "${path}"
    top_paths+=("${path}")
    [[ "${#top_paths[@]}" -ge "${top_n}" ]] && break
  done < <(_fs_du_depth1_sorted "${home}")

  local child child_n=6
  [[ "${limit}" != "full" && "${top_n}" -lt 6 ]] && child_n="${top_n}"
  for child in "${top_paths[@]+"${top_paths[@]}"}"; do
    [[ -d "${child}" ]] || continue
    local n=0
    while read -r kb path; do
      [[ -z "${path:-}" ]] && continue
      if constraints_path_excluded "${path}"; then
        continue
      fi
      human="$(numfmt --to=iec --suffix=B "$((kb * 1024))" 2>/dev/null || printf '%sK' "${kb}")"
      printf '%s\t%s\n' "${human}" "${path}"
      n=$((n + 1))
      [[ "${n}" -ge "${child_n}" ]] && break
    done < <(_fs_du_depth1_sorted "${child}")
  done
}

fs_print_filesystem() {
  local home="$1"
  local line size path
  local -a rows=()
  local mode

  ui_section "Filesystem (selected targets)"
  ui_item note "sizes omit regenerable trees (node_modules, .venv, …) unless the target is itself a cache"

  if [[ "${LINUXBKUP_INSPECT_QUICK:-0}" -eq 1 ]]; then
    ui_item note "sizes skipped — LINUXBKUP_INSPECT_QUICK=1"
    while IFS= read -r path; do
      [[ -z "${path}" ]] && continue
      rows+=("  ·  $(term_path_link "${path}")")
    done < <(fs_collect_size_targets "${home}")
    printf '%s\n' "${rows[@]+"${rows[@]}"}" | constraints_list_apply
    constraints_list_footer "targets"
    printf '\n'
    ui_section "Large items under home"
    ui_item note "skipped — LINUXBKUP_INSPECT_QUICK=1"
    return 0
  fi

  while IFS= read -r path; do
    [[ -z "${path}" ]] && continue
    mode="filtered"
    if constraints_is_regenerable_path "${path}"; then
      mode="raw"
    fi
    if line="$(fs_du_sh "${path}" "${mode}")"; then
      size="${line%%$'\t'*}"
      rows+=("$(printf '  %6s  %s' "${size}" "$(term_path_link "${path}")")")
    fi
  done < <(fs_collect_size_targets "${home}")

  if [[ "${#rows[@]}" -eq 0 ]]; then
    ui_item note "none matched constraints (check --no-defaults / --include / --exclude)"
  else
    printf '%s\n' "${rows[@]}" | constraints_list_apply
    constraints_list_footer "targets"
  fi

  printf '\n'
  ui_section "Large items under home (≥ ~100MB, shallow, filter stack)"
  rows=()
  while IFS=$'\t' read -r size path; do
    [[ -z "${path:-}" ]] && continue
    rows+=("$(printf '  %8s  %s' "${size}" "$(term_path_link "${path}")")")
  done < <(fs_home_large_dirs "${home}")

  if [[ "${#rows[@]}" -eq 0 ]]; then
    ui_item note "none above threshold, or home unreadable"
  else
    printf '%s\n' "${rows[@]}" | constraints_list_apply
    constraints_list_footer "large items"
  fi
}
