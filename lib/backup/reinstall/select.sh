# shellcheck shell=bash
# Project picker v2 (split from reinstall.sh — R1 + phase 11).
# Default = skip-none (all). Modes: e=exclude, i=include-only, p=PM, g=grep, f=fzf, n=none.
# Enter/a = all (current behavior). u = undo last mode. q = skip step.
# Nameref rule: always pass the caller's variable *name*.

# Display line for one row.
# Args: index1 pm path cmd
reinstall_picker_line() {
  local idx="$1" pm="$2" path="$3" cmd="$4"
  printf '  [%d] %-6s  %s  (%s)' "${idx}" "${pm}" "${path}" "${cmd}"
}

# Selected/total counts + PM breakdown for a want-set.
# Args: rows_array_name want_set_name
# Prints: selected_n<TAB>total_n<TAB>"npm 16, pnpm 121"
reinstall_picker_counts() {
  local -n _pc_rows="$1"
  local -n _pc_want="$2"
  local i n path pm lock cmd
  local -A cnt=()
  local selected=0 total=0 parts="" p
  local -a pm_keys=()

  n="${#_pc_rows[@]}"
  for ((i = 0; i < n; i++)); do
    total=$((total + 1))
    [[ -n "${_pc_want[${i}]+x}" ]] || continue
    selected=$((selected + 1))
    IFS=$'\t' read -r path pm lock cmd <<<"${_pc_rows[i]}" || true
    [[ -n "${pm}" ]] || continue
    cnt["${pm}"]=$((${cnt["${pm}"]:-0} + 1))
  done
  if [[ "${#cnt[@]}" -gt 0 ]]; then
    mapfile -t pm_keys < <(printf '%s\n' "${!cnt[@]}" | sort)
    for p in "${pm_keys[@]}"; do
      [[ -n "${p}" ]] || continue
      parts="${parts:+${parts}, }${p} ${cnt[${p}]}"
    done
  fi
  printf '%s\t%s\t%s\n' "${selected}" "${total}" "${parts}"
}

# Apply exclude/include selection text → want-set.
# Args: n text want_set_name mode(exclude|include)
# shellcheck source=lib/ask/select.sh
[[ -n "${LINUXBKUP_ROOT:-}" ]] && source "${LINUXBKUP_ROOT}/lib/ask/select.sh"
reinstall_picker_apply_indices() {
  local n="$1" text="$2" want_name="$3" mode="$4"
  local -n _pa_want="${want_name}"
  local i
  _pa_want=()
  if [[ "${mode}" == "include" ]]; then
    while IFS= read -r i; do
      [[ -z "${i}" ]] && continue
      i=$((i - 1))
      [[ "${i}" -ge 0 && "${i}" -lt "${n}" ]] && _pa_want["${i}"]=1
    done < <(ask_parse_selection "${n}" "${text}")
  else
    for ((i = 0; i < n; i++)); do _pa_want["${i}"]=1; done
    while IFS= read -r i; do
      [[ -z "${i}" ]] && continue
      i=$((i - 1))
      [[ "${i}" -ge 0 && "${i}" -lt "${n}" ]] && unset "_pa_want[${i}]"
    done < <(ask_parse_selection "${n}" "${text}")
  fi
}

# Apply PM filter → want-set (rows matching PM only).
# Args: rows_array_name text want_set_name
reinstall_picker_apply_pm() {
  local -n _pap_rows="$1"
  local text="$2"
  local -n _pap_want="$3"
  local i n path pm lock cmd
  local -A keep=()
  local p

  text="$(printf '%s' "${text}" | tr '[:upper:]' '[:lower:]' | tr ' ' ',')"
  for p in ${text//,/ }; do
    [[ -n "${p}" ]] && keep["${p}"]=1
  done
  n="${#_pap_rows[@]}"
  _pap_want=()
  [[ "${#keep[@]}" -eq 0 ]] && return 0
  for ((i = 0; i < n; i++)); do
    IFS=$'\t' read -r path pm lock cmd <<<"${_pap_rows[i]}" || true
    [[ -n "${keep[${pm}]+x}" ]] && _pap_want["${i}"]=1
  done
}

# Apply grep/substring filter → want-set (paths containing text).
# Args: rows_array_name text want_set_name
reinstall_picker_apply_grep() {
  local -n _pag_rows="$1"
  local text="$2"
  local -n _pag_want="$3"
  local i n path pm lock cmd

  n="${#_pag_rows[@]}"
  _pag_want=()
  [[ -z "${text}" ]] && return 0
  for ((i = 0; i < n; i++)); do
    IFS=$'\t' read -r path pm lock cmd <<<"${_pag_rows[i]}" || true
    [[ "${path}" == *"${text}"* ]] && _pag_want["${i}"]=1
  done
}

# fzf multi-select → want-set. Args: rows_array_name want_set_name
# Esc/empty → all (same as Enter).
reinstall_picker_fzf() {
  local -n _fzf_rows="$1"
  local -n _fzf_want="$2"
  local i n path pm lock cmd line
  local -a fzf_in=() fzf_out=()

  n="${#_fzf_rows[@]}"
  _fzf_want=()
  command -v fzf >/dev/null 2>&1 || return 1
  for ((i = 0; i < n; i++)); do
    IFS=$'\t' read -r path pm lock cmd <<<"${_fzf_rows[i]}" || true
    fzf_in+=("$(printf '%d\t%s\t%s\t%s' "$((i + 1))" "${pm}" "${path}" "${cmd}")")
  done
  mapfile -t fzf_out < <(
    printf '%s\n' "${fzf_in[@]}" | fzf -m \
      --header="TAB select · Enter confirm · Esc abort" \
      --with-nth=2,3,4 --delimiter=$'\t' || true
  )
  if [[ "${#fzf_out[@]}" -eq 0 ]]; then
    for ((i = 0; i < n; i++)); do _fzf_want["${i}"]=1; done
    return 0
  fi
  for line in "${fzf_out[@]}"; do
    i="${line%%$'\t'*}"
    i=$((i - 1))
    [[ "${i}" -ge 0 && "${i}" -lt "${n}" ]] && _fzf_want["${i}"]=1
  done
  return 0
}

# Copy want-set → out array of rows (in order).
# Args: in_array_name want_set_name out_array_name
reinstall_picker_materialize() {
  local -n _pm_in="$1"
  local -n _pm_want="$2"
  local -n _pm_out="$3"
  local i n

  _pm_out=()
  n="${#_pm_in[@]}"
  for ((i = 0; i < n; i++)); do
    [[ -n "${_pm_want[${i}]+x}" ]] || continue
    _pm_out+=("${_pm_in[i]}")
  done
}

# Interactive picker v2. Returns 0 = run selection; 1 = skip step (q).
# -y / non-TTY: all projects (safe default). --ask or plain TTY: picker.
# Args: in_array_name out_array_name
reinstall_select_node() {
  local in_name="$1"
  local out_name="$2"
  local -n _sel_in="${in_name}"
  local -n _sel_out="${out_name}"
  local n i path pm lock cmd line sel_n tot_n pm_counts
  local -A want=() want_prev=()
  local -A want_undo=()
  local undo_n=0
  local interactive=0
  local mode="action" # action | confirm
  local reply=""
  local -a display=() counts_parts=()

  _sel_out=()
  n="${#_sel_in[@]}"
  [[ "${n}" -gt 0 ]] || return 0

  if [[ "${LINUXBKUP_YES:-0}" -ne 1 && -t 0 ]]; then
    interactive=1
  fi
  if [[ "${LINUXBKUP_ASK:-0}" -eq 1 && -t 0 ]]; then
    interactive=1
  fi
  if [[ "${interactive}" -ne 1 ]]; then
    _sel_out=("${_sel_in[@]}")
    return 0
  fi

  # shellcheck source=lib/ask/select.sh
  source "${LINUXBKUP_ROOT}/lib/ask/select.sh"
  # shellcheck source=lib/constraints/list.sh
  source "${LINUXBKUP_ROOT}/lib/constraints/list.sh"

  ui_section "Reinstall — pick projects"
  ui_item note "node_modules were not backed up — pick projects to regenerate"
  if [[ "${n}" -gt 20 ]] && command -v fzf >/dev/null 2>&1; then
    ui_item note "large list — fzf multi-select available (f)"
  fi
  printf '\n'

  # Default = all (skip-none)
  for ((i = 0; i < n; i++)); do want["${i}"]=1; done

  _reinstall_picker_render() {
    local s t c
    IFS=$'\t' read -r s t c <<<"$(reinstall_picker_counts "${in_name}" want)" || true
    printf '  %s of %s selected%s\n' "${s}" "${t}" "${c:+ (${c})}"
  }

  _reinstall_picker_save_undo() {
    local k
    want_undo=()
    if [[ "${#want[@]}" -gt 0 ]]; then
      for k in "${!want[@]}"; do
        [[ -n "${k}" ]] && want_undo["${k}"]=1
      done
    fi
    undo_n=1
  }

  while true; do
    if [[ "${mode}" == "action" ]]; then
      _reinstall_picker_render
      printf '\n'
      ui_item note "All selected. Action:"
      printf '    [a]ll (current)  [e]xclude some  [i]nclude only  [p]M filter\n'
      printf '    [g]rep path filter  [f]fzf  [n]one  [q]skip step\n'
      if [[ "${undo_n}" -gt 0 ]]; then
        printf '    [u]ndo last mode\n'
      fi
    else
      _reinstall_picker_render
      printf '  [Enter] run · [u]ndo · [q]back\n'
    fi
    read -r -p "> " reply || reply="q"

    if [[ "${mode}" == "confirm" ]]; then
      case "${reply}" in
        ""|r|R|run)
          break
          ;;
        u|U|undo)
          if [[ "${undo_n}" -gt 0 ]]; then
            want=()
            local k
            if [[ "${#want_undo[@]}" -gt 0 ]]; then
              for k in "${!want_undo[@]}"; do
                [[ -n "${k}" ]] && want["${k}"]=1
              done
            fi
            undo_n=0
            mode="action"
          fi
          continue
          ;;
        q|Q|back)
          mode="action"
          continue
          ;;
        a|A|all)
          want=()
          for ((i = 0; i < n; i++)); do want["${i}"]=1; done
          mode="action"
          continue
          ;;
        *)
          continue
          ;;
      esac
    fi

    # Action mode
    case "${reply}" in
      q|Q|quit)
        log_skip "reinstall step skipped by user"
        return 1
        ;;
      ""|a|A|all|ALL)
        want=()
        for ((i = 0; i < n; i++)); do want["${i}"]=1; done
        mode="confirm"
        continue
        ;;
      n|N|none|NONE)
        _reinstall_picker_save_undo
        want=()
        mode="confirm"
        continue
        ;;
      e|E|exclude)
        _reinstall_picker_save_undo
        printf '\n'
        printf '  Exclude — numbers/ranges (1,2,5-9):\n'
        read -r -p "> " reply || reply=""
        reinstall_picker_apply_indices "${n}" "${reply}" want exclude
        mode="confirm"
        continue
        ;;
      i|I|include|inc)
        _reinstall_picker_save_undo
        printf '\n'
        printf '  Include only — numbers/ranges (1,2,5-9):\n'
        read -r -p "> " reply || reply=""
        reinstall_picker_apply_indices "${n}" "${reply}" want include
        mode="confirm"
        continue
        ;;
      p|P|pm)
        _reinstall_picker_save_undo
        printf '\n'
        printf '  PM filter — pnpm / npm / yarn / bun (comma or space):\n'
        read -r -p "> " reply || reply=""
        reinstall_picker_apply_pm "${in_name}" "${reply}" want
        mode="confirm"
        continue
        ;;
      g|G|grep)
        _reinstall_picker_save_undo
        printf '\n'
        printf '  Grep path filter — substring (e.g. workers):\n'
        read -r -p "> " reply || reply=""
        reinstall_picker_apply_grep "${in_name}" "${reply}" want
        mode="confirm"
        continue
        ;;
      f|F|fzf)
        if ! command -v fzf >/dev/null 2>&1; then
          log_warn "fzf not installed — run: linuxbkup deps install fzf"
          continue
        fi
        _reinstall_picker_save_undo
        reinstall_picker_fzf "${in_name}" want || continue
        mode="confirm"
        continue
        ;;
      u|U|undo)
        if [[ "${undo_n}" -gt 0 ]]; then
          want=()
          local k
          if [[ "${#want_undo[@]}" -gt 0 ]]; then
            for k in "${!want_undo[@]}"; do
              [[ -n "${k}" ]] && want["${k}"]=1
            done
          fi
          undo_n=0
        fi
        continue
        ;;
      *)
        # Bare numbers on action = exclude (muscle memory from v1)
        if [[ "${reply}" =~ ^[0-9,\-]+$ ]]; then
          _reinstall_picker_save_undo
          reinstall_picker_apply_indices "${n}" "${reply}" want exclude
          mode="confirm"
          continue
        fi
        log_warn "unknown choice — a/e/i/p/g/f/n/u/q or Enter"
        continue
        ;;
    esac
  done

  reinstall_picker_materialize "${in_name}" want "${out_name}"
  IFS=$'\t' read -r sel_n tot_n pm_counts <<<"$(reinstall_picker_counts "${in_name}" want)" || true
  ui_kv "Selected" "${sel_n}/${tot_n}${pm_counts:+ (${pm_counts})}"
  return 0
}
