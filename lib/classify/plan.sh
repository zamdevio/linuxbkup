# shellcheck shell=bash
# Human / machine plan output from classify_scan_home.

# shellcheck source=lib/classify/scan.sh
source "${LINUXBKUP_ROOT}/lib/classify/scan.sh"

# Print classification plan. Args: home
classify_print_plan() {
  local home="$1"
  local path class action size reason
  local -a unexpected=() include_rows=() skip_rows=() secret_rows=()
  local n_un=0 n_in=0 n_sk=0 n_se=0

  ui_section "Home classification plan"
  ui_item note "Shallow scan of \$HOME + ~/.local/* — regenerable sizes use filter stack"
  printf '\n'

  if [[ "${LINUXBKUP_INSPECT_QUICK:-0}" -eq 1 ]]; then
    ui_item note "sizes skipped — LINUXBKUP_INSPECT_QUICK=1"
  fi

  while IFS=$'\t' read -r path class action size reason; do
    [[ -z "${path:-}" ]] && continue
    case "${class}" in
      unexpected)
        unexpected+=("$(printf '  %8s  %-10s  %s  (%s)' "${size}" "${action}" "$(term_path_link "${path}")" "${reason}")")
        n_un=$((n_un + 1))
        ;;
      secret)
        secret_rows+=("$(printf '  %8s  %-10s  %s  (%s)' "${size}" "${action}" "$(term_path_link "${path}")" "${reason}")")
        n_se=$((n_se + 1))
        ;;
      skip)
        skip_rows+=("$(printf '  %8s  %-10s  %s  (%s)' "${size}" "${action}" "$(term_path_link "${path}")" "${reason}")")
        n_sk=$((n_sk + 1))
        ;;
      include)
        include_rows+=("$(printf '  %8s  %-10s  %s  (%s)' "${size}" "${action}" "$(term_path_link "${path}")" "${reason}")")
        n_in=$((n_in + 1))
        ;;
    esac
  done < <(classify_scan_home "${home}")

  printf '  Known include (%d):\n' "${n_in}"
  if [[ "${n_in}" -eq 0 ]]; then
    ui_item note "none"
  else
    printf '%s\n' "${include_rows[@]}" | constraints_list_apply
    constraints_list_footer "known include"
  fi

  printf '  Secrets (%d):\n' "${n_se}"
  if [[ "${n_se}" -eq 0 ]]; then
    ui_item note "none"
  else
    printf '%s\n' "${secret_rows[@]}" | constraints_list_apply
    constraints_list_footer "secrets"
  fi

  printf '  Skip / regenerable (%d):\n' "${n_sk}"
  if [[ "${n_sk}" -eq 0 ]]; then
    ui_item note "none"
  else
    printf '%s\n' "${skip_rows[@]}" | constraints_list_apply
    constraints_list_footer "skip"
  fi

  printf '  Unexpected (%d):\n' "${n_un}"
  if [[ "${n_un}" -eq 0 ]]; then
    ui_item note "none"
  else
    printf '%s\n' "${unexpected[@]}" | constraints_list_apply
    constraints_list_footer "unexpected"
    if [[ "${LINUXBKUP_YES:-0}" -eq 1 ]] || [[ ! -t 0 ]]; then
      ui_item note "unexpected → auto-include (--yes or non-TTY)"
    else
      ui_item note "unexpected → ask on backup (pass -y to auto-include)"
    fi
  fi

  if [[ "${LINUXBKUP_JSON:-0}" -eq 1 ]]; then
    printf '\n'
    ui_section "Plan (TSV)"
    printf 'path\tclass\taction\tsize\treason\n'
    classify_scan_home "${home}"
  fi
}
