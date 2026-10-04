#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="${ROOT}/linuxbkup"
fail=0

ok() { printf 'OK  %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

if [[ ! -x "${CLI}" ]]; then
  bad "entry binary linuxbkup missing"
  exit 1
fi

if "${CLI}" --help >/dev/null; then ok "help exits 0"; else bad "help exits 0"; fi

ver="$("${CLI}" --no-color version 2>/dev/null)"
if [[ "${ver}" == *Version* && ( "${ver}" == *dev* || "${ver}" == *0.* ) ]]; then
  ok "version prints"
else
  bad "version prints"
fi

help_out="$("${CLI}" --no-color --help 2>/dev/null)" || true
if [[ "${help_out}" == *"Commands"* && "${help_out}" == *"inspect"* && "${help_out}" == *"deps"* && "${help_out}" == *"plan"* ]]; then
  ok "styled help lists commands"
else
  bad "styled help lists commands"
fi

if [[ "${help_out}" == *"desktop Linux, VPS, and WSL"* ]]; then
  ok "help mentions desktop/VPS/WSL"
else
  bad "help mentions desktop/VPS/WSL"
fi

if "${CLI}" --no-color help deps >/dev/null 2>&1; then ok "help deps"; else bad "help deps"; fi

out="$(env LINUXBKUP_INSPECT_QUICK=1 "${CLI}" --no-color --no-links inspect 2>/dev/null)" || true
if [[ "${out}" == *"Environment inspection"* && "${out}" == *"Distribution"* && "${out}" == *"Backup destination"* && "${out}" == *"Tools"* ]]; then
  ok "inspect reports environment"
else
  bad "inspect reports environment"
fi

deps_out="$("${CLI}" --no-color deps status 2>/dev/null)" || true
if [[ "${deps_out}" == *"Core"* && "${deps_out}" == *"Installed"* && "${deps_out}" == *"Missing"* ]]; then
  ok "deps status reports catalog"
else
  bad "deps status reports catalog"
fi

inst_out="$("${CLI}" --no-color deps install age 2>/dev/null)" || true
if [[ "${inst_out}" == *"Already installed"* || "${inst_out}" == *"already present"* || "${inst_out}" == *"Status"* ]]; then
  ok "deps install skips present tools"
else
  bad "deps install skips present tools"
fi

if env LINUXBKUP_TEST=1 "${CLI}" --no-color nope >/dev/null 2>&1; then
  bad "unknown command should fail"
else
  ok "unknown command fails"
fi

if "${CLI}" --no-color restore >/dev/null 2>&1; then
  bad "restore without arg should fail"
else
  ok "restore without arg fails"
fi

if bash -n "${CLI}" \
  && bash -n "${ROOT}"/lib/core/*.sh \
  && bash -n "${ROOT}"/lib/core/terminal/*.sh \
  && bash -n "${ROOT}"/lib/core/platform/*.sh \
  && bash -n "${ROOT}"/lib/cmd/*.sh \
  && bash -n "${ROOT}"/lib/env/*.sh \
  && bash -n "${ROOT}"/lib/fs/*.sh \
  && bash -n "${ROOT}"/lib/classify/*.sh \
  && bash -n "${ROOT}"/lib/constraints/*.sh \
  && bash -n "${ROOT}"/lib/tools/*.sh \
  && bash -n "${ROOT}"/lib/backup/*.sh \
  && bash -n "${ROOT}"/lib/archive/*.sh \
  && bash -n "${ROOT}"/modules/*.sh; then
  ok "bash -n syntax"
else
  bad "bash -n syntax"
fi

bak_out="$("${CLI}" --no-color -y --dry-run -o /tmp/linuxbkup-smoke-dry.tar.zst backup 2>/dev/null)" || true
if [[ "${bak_out}" == *"dry-run"* && "${bak_out}" == *"Backup"* && "${bak_out}" == *"Run:"* && "${bak_out}" == *"plan"* && "${bak_out}" == *"-y"* ]]; then
  ok "backup dry-run plans"
else
  bad "backup dry-run plans"
fi

# Identity gate: previous product binary/env prefix must not appear in the tree.
# Pattern is assembled at runtime so the old strings never live in source.
_old_bin="$(printf '%s%s' 'wsl' 'bkup')"
_old_env="$(printf '%s%s' 'WSL' 'BKUP')"
if command -v rg >/dev/null 2>&1; then
  if rg -i "${_old_bin}|${_old_env}" --glob '!.git/**' "${ROOT}" >/dev/null 2>&1; then
    bad "identity: previous product name still present"
    rg -i "${_old_bin}|${_old_env}" --glob '!.git/**' "${ROOT}" || true
  else
    ok "identity: previous product name absent"
  fi
else
  if grep -RInE "${_old_bin}|${_old_env}" \
    --exclude-dir=.git \
    "${ROOT}" >/dev/null 2>&1; then
    bad "identity: previous product name still present"
  else
    ok "identity: previous product name absent"
  fi
fi

# Platform dest default: native helper is always under ~/Backups/linuxbkup
LINUXBKUP_ROOT="${ROOT}"
export LINUXBKUP_ROOT
# shellcheck source=/dev/null
source "${ROOT}/lib/core/common.sh"
# shellcheck source=/dev/null
source "${ROOT}/lib/core/platform/paths.sh"
native="$(platform_native_backup_dir)"
if [[ "${native}" == */Backups/linuxbkup ]]; then
  ok "native backup dir under Backups/linuxbkup"
else
  bad "native backup dir under Backups/linuxbkup"
fi

# Portable rules: no host-shaped project dirnames in shipped defaults
# shellcheck source=/dev/null
source "${ROOT}/lib/constraints/base.sh"
joined="${CONSTRAINTS_RULE_INCLUDE_DIRS[*]} ${CONSTRAINTS_RULE_INCLUDE_FILES[*]} ${CONSTRAINTS_IMPORTANT_TARGETS[*]}"
if [[ "${joined}" == *Projects* || "${joined}" == *Workers* || "${joined}" == *Tools* ]]; then
  bad "portable: no host-shaped dirnames in rules/important lists"
else
  ok "portable: no host-shaped dirnames in rules/important lists"
fi

# Filter stack produces du --exclude args
excl=()
constraints_du_exclude_args excl
if [[ "${#excl[@]}" -ge 3 && "${excl[*]}" == *node_modules* ]]; then
  ok "filter stack: du excludes regenerables"
else
  bad "filter stack: du excludes regenerables"
fi

staging_fixture="${ROOT}/tests/fixtures/staging-ok"
if [[ -d "${staging_fixture}" && -f "${staging_fixture}/checksums.sha256" ]]; then
  if "${CLI}" --no-color verify "${staging_fixture}" >/dev/null 2>&1; then
    ok "verify staging fixture"
  else
    bad "verify staging fixture"
  fi
  if "${CLI}" --no-color verify "${ROOT}/tests/fixtures/not-staging" >/dev/null 2>&1; then
    bad "verify rejects non-staging dir"
  else
    ok "verify rejects non-staging dir"
  fi
else
  bad "verify staging fixture missing"
fi

# Phase 02: fake home — unexpected paths auto-included with --yes
fake_home="$(mktemp -d "${TMPDIR:-/tmp}/linuxbkup-smoke-home.XXXXXX")"
mkdir -p "${fake_home}/.config" "${fake_home}/.local/bin" "${fake_home}/.local/custom-dir" "${fake_home}/work"
printf 'x\n' >"${fake_home}/.bashrc"
printf 'y\n' >"${fake_home}/.local/custom-dir/f"
# shellcheck source=/dev/null
source "${ROOT}/lib/fs/sizes.sh"
# shellcheck source=/dev/null
source "${ROOT}/lib/classify/scan.sh"
plan_out="$(LINUXBKUP_YES=1 LINUXBKUP_INSPECT_QUICK=1 classify_scan_home "${fake_home}")"
if echo "${plan_out}" | grep -F "${fake_home}/.local/custom-dir" | grep -q $'unexpected\tinclude'; then
  ok "classify: unexpected .local/custom-dir auto-include with --yes"
else
  bad "classify: unexpected .local/custom-dir auto-include with --yes"
  echo "${plan_out}" | head -30 || true
fi
if echo "${plan_out}" | grep -F "${fake_home}/work" | grep -q $'unexpected\tinclude'; then
  ok "classify: unexpected top-level work auto-include with --yes"
else
  bad "classify: unexpected top-level work auto-include with --yes"
fi
mkdir -p "${fake_home}/go/pkg/mod"
go_row="$(LINUXBKUP_YES=1 LINUXBKUP_INSPECT_QUICK=1 classify_scan_home "${fake_home}" | grep -F "${fake_home}/go" | head -1 || true)"
if [[ "${go_row}" == *$'\tskip\t'* ]]; then
  ok "classify: ~/go default skip"
else
  bad "classify: ~/go default skip"
  echo "${go_row}" || true
fi
# --exclude: ~, trailing slash, basename (path-like, not naive ERE)
# shellcheck source=/dev/null
source "${ROOT}/lib/constraints/base.sh"
LINUXBKUP_HOME="${fake_home}"
export LINUXBKUP_HOME
mkdir -p "${fake_home}/Product" "${fake_home}/.local/share" "${fake_home}/Projects"
LINUXBKUP_EXCLUDE_REGEXES=("Projects" "~/.local/share" "${fake_home}/Product/")
ex_ok=1
constraints_path_excluded "${fake_home}/Projects" || ex_ok=0
constraints_path_excluded "${fake_home}/.local/share" || ex_ok=0
constraints_path_excluded "${fake_home}/Product" || ex_ok=0
constraints_path_excluded "${fake_home}/.config" && ex_ok=0
if [[ "${ex_ok}" -eq 1 ]]; then
  ok "exclude matches ~ basename and trailing slash"
else
  bad "exclude matches ~ basename and trailing slash"
fi
unset LINUXBKUP_EXCLUDE_REGEXES
LINUXBKUP_EXCLUDE_REGEXES=()
if ! grep -qE '^\s*/tmp\s*$' "${ROOT}/lib/constraints/size_targets.sh"; then
  ok "size_targets: /tmp not default-scanned"
else
  bad "size_targets: /tmp not default-scanned"
fi
# shellcheck source=/dev/null
source "${ROOT}/lib/fs/sizes.sh"
if [[ "$(fs_parse_size_to_bytes 2M)" == "2097152" ]]; then
  ok "fs_parse_size_to_bytes 2M"
else
  bad "fs_parse_size_to_bytes 2M"
fi
help_max="$("${CLI}" --no-color --help 2>/dev/null)" || true
if [[ "${help_max}" == *"--max-size"* ]]; then
  ok "help lists --max-size"
else
  bad "help lists --max-size"
fi
# --max-size stage gate (unit): staging over limit → fail
max_stage="$(mktemp -d "${TMPDIR:-/tmp}/linuxbkup-smoke-stage.XXXXXX")"
dd if=/dev/zero of="${max_stage}/blob" bs=2048 count=1 status=none 2>/dev/null || head -c 2048 /dev/zero >"${max_stage}/blob"
# shellcheck source=/dev/null
source "${ROOT}/lib/constraints/base.sh"
# shellcheck source=/dev/null
source "${ROOT}/lib/core/terminal/style.sh"
# shellcheck source=/dev/null
source "${ROOT}/lib/core/terminal/control.sh"
# shellcheck source=/dev/null
source "${ROOT}/lib/core/terminal/progress.sh"
# shellcheck source=/dev/null
source "${ROOT}/lib/backup/home.sh"
LINUXBKUP_MAX_SIZE_BYTES=100
if backup_check_max_size "${max_stage}" 2>/dev/null; then
  bad "backup_check_max_size enforces limit"
else
  ok "backup_check_max_size enforces limit"
fi
rm -rf "${max_stage}"
unset LINUXBKUP_MAX_SIZE_BYTES
if "${CLI}" --no-color --no-links plan >/dev/null 2>&1; then
  ok "plan exits 0"
else
  bad "plan exits 0"
fi
json_out="$("${CLI}" --no-color --json plan 2>/dev/null)" || true
if [[ "${json_out}" == *'"schema": "linuxbkup.plan/v1"'* && "${json_out}" == *'"entries"'* ]]; then
  ok "plan --json envelope"
else
  bad "plan --json envelope"
fi
if [[ -f "${ROOT}/guides/tools/fzf.guide" ]]; then
  ok "fzf guide present"
else
  bad "fzf guide present"
fi

# Flag tips + progress helpers load
# shellcheck source=/dev/null
source "${ROOT}/lib/core/cli_tips.sh"
# shellcheck source=/dev/null
source "${ROOT}/lib/core/terminal/style.sh"
tip_flags=()
LINUXBKUP_YES=1
LINUXBKUP_NO_SECRETS=1
linuxbkup_flags_backup_relevant tip_flags
tip_joined="${tip_flags[*]}"
if [[ "${tip_joined}" == *-y* && "${tip_joined}" == *no-secrets* ]]; then
  ok "flag tips replay -y and --no-secrets"
else
  bad "flag tips replay -y and --no-secrets"
fi
if declare -F term_progress_begin >/dev/null && declare -F term_notify >/dev/null; then
  ok "terminal progress/notify helpers loaded"
else
  bad "terminal progress/notify helpers loaded"
fi

# plan tip mentions backup with flags
tip_out="$("${CLI}" --no-color -y --no-secrets plan 2>/dev/null)" || true
if [[ "${tip_out}" == *"linuxbkup"* && "${tip_out}" == *"backup"* && "${tip_out}" == *"-y"* ]]; then
  ok "plan tip includes flagged backup command"
else
  bad "plan tip includes flagged backup command"
fi

rm -rf "${fake_home}"

exit "${fail}"
