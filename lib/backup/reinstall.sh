# shellcheck shell=bash
# Thin loader — split lives in lib/backup/reinstall/*.sh
# Call sites keep: source "${LINUXBKUP_ROOT}/lib/backup/reinstall.sh"
_reinstall_dir="${LINUXBKUP_ROOT}/lib/backup/reinstall"
# shellcheck source=lib/backup/reinstall/manifest.sh
source "${_reinstall_dir}/manifest.sh"
# shellcheck source=lib/backup/reinstall/pm.sh
source "${_reinstall_dir}/pm.sh"
# shellcheck source=lib/backup/reinstall/preflight.sh
source "${_reinstall_dir}/preflight.sh"
# shellcheck source=lib/backup/reinstall/select.sh
source "${_reinstall_dir}/select.sh"
# shellcheck source=lib/backup/reinstall/run_one.sh
source "${_reinstall_dir}/run_one.sh"
# shellcheck source=lib/backup/reinstall/run.sh
source "${_reinstall_dir}/run.sh"
unset _reinstall_dir
