# shellcheck shell=bash
# Numbered multi-select (fzf optional) for backup path decisions.

# Parse selection text into 1-based indices (stdout, one per line).
# Supports: 1,2,4-6  a=all  n=none  empty=accept suggestions
# Args: max_index  selection_text  [mode=toggle|accept]
ask_parse_selection() {
  local max="$1" text="${2:-}" mode="${3:-toggle}"
  local part a b i
  text="$(printf '%s' "${text}" | tr -d '[:space:]')"
  if [[ -z "${text}" ]]; then
    return 0
  fi
  case "${text}" in
    a|A|all|ALL)
      for ((i = 1; i <= max; i++)); do printf '%s\n' "${i}"; done
      return 0
      ;;
    n|N|none|NONE)
      return 0
      ;;
  esac
  IFS=',' read -r -a parts <<<"${text}" || true
  for part in "${parts[@]+"${parts[@]}"}"; do
    [[ -z "${part}" ]] && continue
    if [[ "${part}" =~ ^([0-9]+)-([0-9]+)$ ]]; then
      a="${BASH_REMATCH[1]}"
      b="${BASH_REMATCH[2]}"
      ((a > b)) && { local t="${a}"; a="${b}"; b="${t}"; }
      for ((i = a; i <= b; i++)); do
        [[ "${i}" -ge 1 && "${i}" -le "${max}" ]] && printf '%s\n' "${i}"
      done
    elif [[ "${part}" =~ ^[0-9]+$ ]]; then
      [[ "${part}" -ge 1 && "${part}" -le "${max}" ]] && printf '%s\n' "${part}"
    else
      log_warn "ignoring bad selection token: ${part}"
    fi
  done
}

# Interactive (or fzf) pick of paths to BACKUP.
# Input nameref: rows of path<TAB>human<TAB>class<TAB>suggested(include|skip)
# Output nameref: paths chosen for backup.
# Returns 1 if user aborts (q).
ask_select_backup_paths() {
  local -n _in_rows="$1"
  local -n _out_paths="$2"
  local title="${3:-Paths to decide}"
  local i n path human class suggested line pick
  local -a idx_selected=()
  local -A want=()
  local use_fzf=0

  _out_paths=()
  n="${#_in_rows[@]}"
  [[ "${n}" -gt 0 ]] || return 0

  ui_section "${title}"
  ui_item note "profile: ${LINUXBKUP_PROFILE:-balanced} — pick what to BACKUP (others keep suggestion)"
  printf '\n'

  for ((i = 0; i < n; i++)); do
    IFS=$'\t' read -r path human class suggested <<<"${_in_rows[i]}" || true
    printf '  [%d] %8s  %-12s  suggested: %-7s  %s\n' \
      "$((i + 1))" "${human}" "${class}" "${suggested}" "$(term_path_link "${path}")"
    if [[ "${suggested}" == "include" ]]; then
      want["${i}"]=1
    fi
  done

  printf '\n'
  ui_item note "numbers/ranges e.g. 1,2 or 1-3  ·  a=all  ·  n=none  ·  Enter=accept suggestions  ·  q=abort"
  if command -v fzf >/dev/null 2>&1 && [[ -t 0 && -t 1 ]]; then
    ui_item note "fzf available — type f then Enter for fuzzy multi-select"
  fi

  if [[ ! -t 0 ]]; then
    log_warn "non-TTY ask — accepting profile suggestions"
  else
    while true; do
      read -r -p "> " pick || pick="q"
      case "${pick}" in
        q|Q|quit|abort)
          log_skip "ask aborted"
          return 1
          ;;
        f|F|fzf)
          if command -v fzf >/dev/null 2>&1; then
            use_fzf=1
            break
          fi
          log_warn "fzf not installed — run: linuxbkup deps install fzf"
          continue
          ;;
        *)
          break
          ;;
      esac
    done

    if [[ "${use_fzf}" -eq 1 ]]; then
      local -a fzf_in=() fzf_out=()
      for ((i = 0; i < n; i++)); do
        IFS=$'\t' read -r path human class suggested <<<"${_in_rows[i]}" || true
        fzf_in+=("$(printf '%d\t%8s\t%-12s\t%s\t%s' "$((i + 1))" "${human}" "${class}" "${suggested}" "${path}")")
      done
      mapfile -t fzf_out < <(
        printf '%s\n' "${fzf_in[@]}" | fzf -m --header="TAB select · Enter confirm · Esc abort" \
          --with-nth=1,2,3,4 --delimiter=$'\t' || true
      )
      if [[ "${#fzf_out[@]}" -eq 0 ]]; then
        # Esc / empty → accept suggestions (same as Enter)
        :
      else
        want=()
        for line in "${fzf_out[@]}"; do
          i="${line%%$'\t'*}"
          i=$((i - 1))
          [[ "${i}" -ge 0 && "${i}" -lt "${n}" ]] && want["${i}"]=1
        done
      fi
    else
      case "${pick}" in
        "")
          ;; # keep want from suggestions
        a|A|all|ALL)
          want=()
          for ((i = 0; i < n; i++)); do want["${i}"]=1; done
          ;;
        n|N|none|NONE)
          want=()
          ;;
        *)
          # Toggle model: start from suggestions, then force-include listed indices
          # Spec: "Select to BACKUP (others keep suggestion)" — listed = backup, unlisted keep suggestion
          want=()
          for ((i = 0; i < n; i++)); do
            IFS=$'\t' read -r path human class suggested <<<"${_in_rows[i]}" || true
            [[ "${suggested}" == "include" ]] && want["${i}"]=1
          done
          while IFS= read -r i; do
            [[ -z "${i}" ]] && continue
            i=$((i - 1))
            want["${i}"]=1
          done < <(ask_parse_selection "${n}" "${pick}")
          # Also: if user typed only numbers, those are additive to suggestions per spec.
          # Spec again: "Select to BACKUP (others keep suggestion)" — so numbers ADD include, don't clear skips.
          ;;
      esac
    fi
  fi

  for ((i = 0; i < n; i++)); do
    [[ -n "${want[${i}]+x}" ]] || continue
    IFS=$'\t' read -r path human class suggested <<<"${_in_rows[i]}" || true
    _out_paths+=("${path}")
  done

  log_verbose "ask selected ${#_out_paths[@]}/${n} paths for backup"
  return 0
}
