# shellcheck shell=bash
# Classification preview — same engine as `linuxbkup plan`.

# shellcheck source=lib/classify/plan.sh
source "${LINUXBKUP_ROOT}/lib/classify/plan.sh"

classify_print_summary() {
  local home="$1"
  classify_print_plan "${home}"
}
