#!/usr/bin/env bash
# Smoke suite — thin runner. Suites live in tests/smoke/NN-*.sh (refactor R-SMOKE).
# See maintainer/phases/refactor.md — do not grow this file past the runner.
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

# Phase 03: --ask wins over --yes
ask_out="$("${CLI}" --no-color --ask -y plan 2>&1)" || true
if [[ "${ask_out}" == *"ignoring --yes because --ask is set"* && "${ask_out}" == *"Ask"* ]]; then
  ok "ask>yes precedence logged"
else
  bad "ask>yes precedence logged"
fi
help03="$("${CLI}" --no-color --help 2>/dev/null)" || true
if [[ "${help03}" == *"--profile"* && "${help03}" == *"--ask"* && "${help03}" == *"--keep-stage"* ]]; then
  ok "help lists profile/ask/keep-stage"
else
  bad "help lists profile/ask/keep-stage"
fi
# shellcheck source=/dev/null
source "${ROOT}/lib/core/profile.sh"
LINUXBKUP_PROFILE=strict
if ! profile_yes_include_large && [[ "$(profile_suggest_large)" == "skip" ]]; then
  ok "profile strict skips large by default"
else
  bad "profile strict skips large by default"
fi
# --stage-dir creates under parent
# shellcheck source=/dev/null
source "${ROOT}/lib/backup/stage.sh"
stage_parent="$(mktemp -d "${TMPDIR:-/tmp}/linuxbkup-smoke-stageparent.XXXXXX")"
LINUXBKUP_STAGE_DIR="${stage_parent}"
stage_path="$(backup_stage_create)" || stage_path=""
if [[ -n "${stage_path}" && -d "${stage_path}" && "${stage_path}" == "${stage_parent}/linuxbkup."* ]]; then
  ok "stage-dir creates under parent"
else
  bad "stage-dir creates under parent"
fi
rm -rf "${stage_parent}"
unset LINUXBKUP_STAGE_DIR

# Phase 04: reclaim candidates + secrets encrypt (expect-driven when available)
# shellcheck source=/dev/null
source "${ROOT}/lib/backup/reclaim.sh"
# shellcheck source=/dev/null
source "${ROOT}/lib/backup/secrets_crypt.sh"
mkdir -p "${fake_home}/.cache/x" "${fake_home}/.ssh"
printf 'k\n' >"${fake_home}/.ssh/id_test"
printf 'c\n' >"${fake_home}/.cache/x/f"
# shellcheck source=/dev/null
source "${ROOT}/lib/classify/scan.sh"
reclaim_scan=()
while IFS= read -r line; do reclaim_scan+=("${line}"); done < <(LINUXBKUP_YES=1 LINUXBKUP_INSPECT_QUICK=1 classify_scan_home "${fake_home}")
reclaim_cands=()
backup_reclaim_candidates reclaim_scan reclaim_cands
if [[ "${#reclaim_cands[@]}" -ge 1 ]]; then
  ok "reclaim candidates from skip set"
else
  bad "reclaim candidates from skip set"
fi
if command -v age >/dev/null 2>&1 && command -v age-keygen >/dev/null 2>&1 && command -v openssl >/dev/null 2>&1; then
  sec_stage="$(mktemp -d "${TMPDIR:-/tmp}/linuxbkup-smoke-sec.XXXXXX")"
  mkdir -p "${sec_stage}/secrets/.ssh" "${sec_stage}/metadata"
  printf 'secret\n' >"${sec_stage}/secrets/.ssh/id_test"
  # Clear tip-test globals that would force exclude/plain
  LINUXBKUP_NO_SECRETS=0
  LINUXBKUP_SECRETS_PLAIN=0
  LINUXBKUP_DRY_RUN=0
  LINUXBKUP_SECRETS_MODE=encrypt
  _sec_pass="smoke-pass-$$"
  export LINUXBKUP_SECRETS_PASS="${_sec_pass}"
  if backup_secrets_encrypt_stage "${sec_stage}" \
    && [[ -f "${sec_stage}/secrets.tar.age" ]] \
    && [[ -f "${sec_stage}/secrets.agekey.enc" ]] \
    && [[ ! -d "${sec_stage}/secrets" ]]; then
    ok "age encrypts secrets and wipes plaintext"
  else
    bad "age encrypts secrets and wipes plaintext"
  fi
  # 04.5 decrypt round-trip (same passphrase)
  LINUXBKUP_SECRETS_PASS="${_sec_pass}"
  export LINUXBKUP_SECRETS_PASS
  LINUXBKUP_FORCE_OVERWRITE=1
  if backup_secrets_decrypt_stage "${sec_stage}" \
    && [[ -f "${sec_stage}/secrets/.ssh/id_test" ]] \
    && grep -q 'secret' "${sec_stage}/secrets/.ssh/id_test"; then
    ok "age decrypt restores secrets tree (04.5)"
  else
    bad "age decrypt restores secrets tree (04.5)"
  fi
  unset LINUXBKUP_FORCE_OVERWRITE LINUXBKUP_SECRETS_PASS LINUXBKUP_SECRETS_MODE
  rm -rf "${sec_stage}"
else
  bad "age encrypts secrets and wipes plaintext (need age+age-keygen+openssl)"
fi

# Node reinstalls capture + detect
# shellcheck source=/dev/null
source "${ROOT}/modules/node.sh"
_nd_home="$(mktemp -d "${TMPDIR:-/tmp}/linuxbkup-smoke-node.XXXXXX")"
mkdir -p "${_nd_home}/app-pnpm" "${_nd_home}/app-npm" "${_nd_home}/mono/packages/lib" \
  "${_nd_home}/skip/node_modules/pkg" "${_nd_home}/.claude/plugins/x"
printf '%s\n' '{"name":"a"}' >"${_nd_home}/app-pnpm/package.json"
printf '\n' >"${_nd_home}/app-pnpm/pnpm-lock.yaml"
printf '%s\n' '{"name":"b"}' >"${_nd_home}/app-npm/package.json"
printf '{}\n' >"${_nd_home}/app-npm/package-lock.json"
printf '%s\n' '{"name":"mono","workspaces":["packages/*"]}' >"${_nd_home}/mono/package.json"
printf '\n' >"${_nd_home}/mono/pnpm-lock.yaml"
printf 'packages:\n  - "packages/*"\n' >"${_nd_home}/mono/pnpm-workspace.yaml"
printf '%s\n' '{"name":"lib"}' >"${_nd_home}/mono/packages/lib/package.json"
printf '%s\n' '{"name":"nested"}' >"${_nd_home}/skip/node_modules/pkg/package.json"
printf '%s\n' '{"name":"noise"}' >"${_nd_home}/.claude/plugins/x/package.json"
touch "${_nd_home}/.claude/plugins/x/pnpm-lock.yaml"
_nd_stage="$(mktemp -d "${TMPDIR:-/tmp}/linuxbkup-smoke-ndst.XXXXXX")"
mkdir -p "${_nd_stage}/home"
cp -a "${_nd_home}/." "${_nd_stage}/home/"
node_capture_manifests "${_nd_stage}"
if [[ -f "${_nd_stage}/packages/reinstalls.json" ]] \
  && grep -q 'app-pnpm' "${_nd_stage}/packages/reinstalls.tsv" \
  && grep -q 'app-npm' "${_nd_stage}/packages/reinstalls.tsv" \
  && grep -q $'^node\tmono\t' "${_nd_stage}/packages/reinstalls.tsv" \
  && ! grep -q 'mono/packages/lib' "${_nd_stage}/packages/reinstalls.tsv" \
  && ! grep -q 'node_modules/pkg' "${_nd_stage}/packages/reinstalls.tsv" \
  && ! grep -q '.claude/' "${_nd_stage}/packages/reinstalls.tsv"; then
  ok "node capture: lockfile roots + workspace dedupe + noise skip"
else
  bad "node capture: lockfile roots + workspace dedupe + noise skip"
fi
# shellcheck source=/dev/null
source "${ROOT}/lib/backup/reinstall.sh"
_nd_rows=()
reinstall_load_node_rows "${_nd_stage}" _nd_rows
if [[ "${#_nd_rows[@]}" -eq 3 ]]; then
  ok "reinstall_load_node_rows reads filtered tsv"
else
  bad "reinstall_load_node_rows reads filtered tsv (n=${#_nd_rows[@]})"
fi
if grep -q 'skip-reinstall' "${ROOT}/lib/core/common.sh" \
  && grep -q 'reinstall-only' "${ROOT}/lib/core/common.sh" \
  && grep -q 'reinstall_ensure_pms' "${ROOT}/lib/backup/reinstall/pm.sh" \
  && grep -q 'reinstall_preflight_guide' "${ROOT}/lib/cmd/restore.sh" \
  && grep -q 'COREPACK_ENABLE_DOWNLOAD_PROMPT=0' "${ROOT}/lib/backup/reinstall/pm.sh" \
  && grep -q 'reinstall_report_lines' "${ROOT}/lib/backup/reinstall/run.sh" \
  && grep -q 'REINSTALL_LAST_REASON' "${ROOT}/lib/backup/reinstall/run_one.sh" \
  && grep -q 'REINSTALL_ONLY' "${ROOT}/lib/cmd/restore.sh"; then
  ok "backup/restore wire reinstall-only + PM ensure + peek preflight"
else
  bad "backup/restore wire reinstall-only + PM ensure + peek preflight"
fi
# R1 split: barrel sources children; call sites unchanged
if grep -q 'source "${_reinstall_dir}/manifest.sh"' "${ROOT}/lib/backup/reinstall.sh" \
  && grep -q 'source "${_reinstall_dir}/run.sh"' "${ROOT}/lib/backup/reinstall.sh" \
  && grep -q 'source "${LINUXBKUP_ROOT}/lib/backup/reinstall.sh"' "${ROOT}/lib/cmd/restore.sh" \
  && [[ -f "${ROOT}/lib/backup/reinstall/select.sh" ]]; then
  ok "R1 reinstall barrel split + restore call site unchanged"
else
  bad "R1 reinstall barrel split + restore call site unchanged"
fi
# Fail-skip + non-interactive PM env + end report helpers
_nd_env="$(reinstall_child_env_args | tr '\n' ' ')"
if [[ "${_nd_env}" == *COREPACK_ENABLE_DOWNLOAD_PROMPT=0* && "${_nd_env}" == *CI=1* ]]; then
  ok "reinstall_child_env_args forces non-interactive PM/corepack"
else
  bad "reinstall_child_env_args forces non-interactive PM/corepack (${_nd_env})"
fi
_nd_home2="$(mktemp -d "${TMPDIR:-/tmp}/linuxbkup-smoke-fail.XXXXXX")"
mkdir -p "${_nd_home2}/ok-app" "${_nd_home2}/bad-app"
printf '%s\n' '{"name":"ok"}' >"${_nd_home2}/ok-app/package.json"
printf '%s\n' '{"name":"bad"}' >"${_nd_home2}/bad-app/package.json"
# missing pm → skip with reason
REINSTALL_LAST_REASON=""
set +e
reinstall_run_one "${_nd_home2}" "ok-app" "definitely-missing-pm-xyz" "definitely-missing-pm-xyz i"
_nd_sk_rc=$?
set -e
if [[ "${_nd_sk_rc}" -eq 2 && -n "${REINSTALL_LAST_REASON}" ]]; then
  ok "reinstall_run_one records skip reason (missing PM)"
else
  bad "reinstall_run_one records skip reason (rc=${_nd_sk_rc} reason=${REINSTALL_LAST_REASON})"
fi
# end-report function + apply summary strings
if declare -F reinstall_report_lines >/dev/null 2>&1 \
  && declare -F reinstall_apply >/dev/null 2>&1; then
  _nd_rep="$(reinstall_report_lines "Failed projects (skipped — re-run later)" \
    $'Workers/push/apps/worker\tERR_PNPM_WORKSPACE_PKG_NOT_FOUND @push/core' 2>&1 || true)"
  if [[ "${_nd_rep}" == *"Failed projects"* && "${_nd_rep}" == *"ERR_PNPM_WORKSPACE_PKG_NOT_FOUND"* ]]; then
    ok "reinstall_report_lines prints path + error reason"
  else
    bad "reinstall_report_lines prints path + error reason"
  fi
else
  bad "reinstall_report_lines / reinstall_apply missing"
fi
# run_one fail keeps log path + reason
mkdir -p "${_nd_home2}/fail-app"
printf '%s\n' '{"name":"f"}' >"${_nd_home2}/fail-app/package.json"
_nd_fakepm="$(mktemp "${TMPDIR:-/tmp}/linuxbkup-smoke-fakepm.XXXXXX")"
printf '#!/bin/sh\necho boom: ERR_TEST_FAIL >&2\nexit 1\n' >"${_nd_fakepm}"
chmod +x "${_nd_fakepm}"
# expose fake as command name via PATH shim dir
_nd_shim="$(mktemp -d "${TMPDIR:-/tmp}/linuxbkup-smoke-shim.XXXXXX")"
ln -s "${_nd_fakepm}" "${_nd_shim}/fakepm"
REINSTALL_LAST_REASON=""
set +e
PATH="${_nd_shim}:${PATH}" reinstall_run_one "${_nd_home2}" "fail-app" "fakepm" "fakepm i"
_nd_fr=$?
set -e
if [[ "${_nd_fr}" -eq 1 && "${REINSTALL_LAST_REASON}" == *ERR_TEST_FAIL* ]]; then
  ok "reinstall_run_one fail keeps error line + non-zero rc"
else
  bad "reinstall_run_one fail keeps error line (rc=${_nd_fr} reason=${REINSTALL_LAST_REASON})"
fi
# apply continues after fail + prints Failed projects report
_nd_stage3="$(mktemp -d "${TMPDIR:-/tmp}/linuxbkup-smoke-apply.XXXXXX")"
mkdir -p "${_nd_stage3}/packages" "${_nd_home2}/app-a" "${_nd_home2}/app-b"
printf '%s\n' '{"name":"a"}' >"${_nd_home2}/app-a/package.json"
printf '%s\n' '{"name":"b"}' >"${_nd_home2}/app-b/package.json"
printf 'node\tapp-a\tfakepm\t-\tfakepm i\nnode\tapp-b\tfakepm\t-\tfakepm i\n' \
  >"${_nd_stage3}/packages/reinstalls.tsv"
_nd_ap_out="$(PATH="${_nd_shim}:${PATH}" LINUXBKUP_YES=1 reinstall_apply "${_nd_stage3}" "${_nd_home2}" 2>&1)" || true
if [[ "${_nd_ap_out}" == *"Reinstall summary"* \
  && "${_nd_ap_out}" == *"Failed projects"* \
  && "${_nd_ap_out}" == *ERR_TEST_FAIL* ]]; then
  ok "reinstall_apply continues after fail + end report"
else
  bad "reinstall_apply continues after fail + end report"
fi
# Phase 11 picker v2 helpers: exclude/include/PM/grep/counts
_nd_rows_pk=(
  $'app-pnpm\tpnpm\t-\tpnpm i'
  $'app-npm\tnpm\t-\tnpm i'
  $'Workers/mailer\tpnpm\t-\tpnpm i'
)
_nd_want=()
reinstall_picker_apply_indices 3 "1,3" _nd_want exclude
_nd_mat=()
reinstall_picker_materialize _nd_rows_pk _nd_want _nd_mat
if [[ "${#_nd_mat[@]}" -eq 1 && "${_nd_mat[0]}" == *app-npm* ]]; then
  ok "picker exclude keeps non-listed rows"
else
  bad "picker exclude keeps non-listed rows (n=${#_nd_mat[@]} mat=${_nd_mat[*]-})"
fi
_nd_want=()
reinstall_picker_apply_indices 3 "2" _nd_want include
_nd_mat=()
reinstall_picker_materialize _nd_rows_pk _nd_want _nd_mat
if [[ "${#_nd_mat[@]}" -eq 1 && "${_nd_mat[0]}" == *app-npm* ]]; then
  ok "picker include-only keeps listed rows"
else
  bad "picker include-only keeps listed rows (n=${#_nd_mat[@]} mat=${_nd_mat[*]-})"
fi
_nd_want=()
reinstall_picker_apply_pm _nd_rows_pk "pnpm" _nd_want
_nd_mat=()
reinstall_picker_materialize _nd_rows_pk _nd_want _nd_mat
if [[ "${#_nd_mat[@]}" -eq 2 ]]; then
  ok "picker PM filter selects pnpm only"
else
  bad "picker PM filter selects pnpm only (n=${#_nd_mat[@]})"
fi
_nd_want=()
reinstall_picker_apply_grep _nd_rows_pk "Workers" _nd_want
_nd_mat=()
reinstall_picker_materialize _nd_rows_pk _nd_want _nd_mat
if [[ "${#_nd_mat[@]}" -eq 1 && "${_nd_mat[0]}" == *Workers* ]]; then
  ok "picker grep filter matches path substring"
else
  bad "picker grep filter matches path substring (n=${#_nd_mat[@]})"
fi
_nd_want=()
for _nd_i in 0 2; do _nd_want[$_nd_i]=1; done
_nd_cnt="$(reinstall_picker_counts _nd_rows_pk _nd_want)"
if [[ "${_nd_cnt}" == $'2\t3\tpnpm 2' ]]; then
  ok "picker counts selected/total + PM breakdown"
else
  bad "picker counts selected/total + PM breakdown (${_nd_cnt})"
fi

# Phase 12c: interrupt menu writes to tty helper + prints What next?
if grep -q '_interrupt_tty' "${ROOT}/lib/core/interrupt.sh"   && grep -q 'What next?' "${ROOT}/lib/core/interrupt.sh"   && grep -q 'applied:' "${ROOT}/lib/core/interrupt.sh"   && grep -q '/dev/tty' "${ROOT}/lib/core/interrupt.sh"; then
  ok "interrupt menu uses tty writer + What next? + applied echo"
else
  bad "interrupt menu uses tty writer + What next? + applied echo"
fi
# Menu body captured when TEST reply set (no hang)
_menu_out="$(
  set +e
  # shellcheck source=/dev/null
  source "${ROOT}/lib/core/common.sh"
  # shellcheck source=/dev/null
  source "${ROOT}/lib/core/terminal/style.sh"
  # shellcheck source=/dev/null
  source "${ROOT}/lib/core/interrupt.sh"
  LINUXBKUP_TEST_INTERRUPT_REPLY=c
  export LINUXBKUP_TEST_INTERRUPT_REPLY
  linuxbkup_op_begin "reinstall-pnpm" "/tmp/proj" 1 1
  linuxbkup_interrupt_menu 2>&1
  exit 0
)" || true
if [[ "${_menu_out}" == *"What next?"* && "${_menu_out}" == *"[s]"* && "${_menu_out}" == *"applied:"*   && "${_menu_out}" == *"Interrupted"* ]]; then
  ok "interrupt menu backup-like (Interrupted + What next? + applied)"
else
  bad "interrupt menu backup-like (out=${_menu_out})"
fi
# No literal backslash-n in menu body
if printf '%s' "${_menu_out}" | grep -qE 'applied:.*\\n|Step:.*\\n|What next\\n'; then
  bad "interrupt menu has literal \\n sequences"
else
  ok "interrupt menu uses real newlines (no literal \\n)"
fi
# nm status + auto-skip helpers
if declare -F reinstall_nm_status >/dev/null 2>&1   && declare -F reinstall_nm_mark >/dev/null 2>&1   && grep -q 'already installed (node_modules present)' "${ROOT}/lib/backup/reinstall/run_one.sh"   && grep -q 'LINUXBKUP_REINSTALL_FORCE' "${ROOT}/lib/backup/reinstall/run_one.sh"; then
  ok "reinstall_nm_status + auto-skip already-installed wired"
else
  bad "reinstall_nm_status + auto-skip already-installed wired"
fi
# selected-only confirm list
if grep -q '_reinstall_picker_show_selected' "${ROOT}/lib/backup/reinstall/select.sh"   && grep -q 'selected only' "${ROOT}/lib/backup/reinstall/select.sh"; then
  ok "picker confirm list is selected-only (no full reprint)"
else
  bad "picker confirm list is selected-only (no full reprint)"
fi
# Immediate ^C notice + graceful stop (TERM → wait → KILL)
if grep -q '_safety_interrupt_notice' "${ROOT}/lib/core/safety.sh"   && grep -q 'Waiting for' "${ROOT}/lib/core/safety.sh"   && grep -q 'REINSTALL_ACTIVE_PM' "${ROOT}/lib/backup/reinstall/run_one.sh"   && grep -q 'kill -KILL' "${ROOT}/lib/core/safety.sh"; then
  ok "interrupt paints PM/pid notice then TERM→wait→KILL"
else
  bad "interrupt paints PM/pid notice then TERM→wait→KILL"
fi
# Notice content includes PM + Project when actives set
_notice_out="$(
  set +e
  # shellcheck source=/dev/null
  source "${ROOT}/lib/core/common.sh"
  # shellcheck source=/dev/null
  source "${ROOT}/lib/core/terminal/style.sh"
  # shellcheck source=/dev/null
  source "${ROOT}/lib/core/safety.sh"
  REINSTALL_ACTIVE_PM=pnpm
  REINSTALL_ACTIVE_REL="Projects/demo"
  REINSTALL_ACTIVE_DIR="/tmp/does-not-exist-demo"
  REINSTALL_ACTIVE_CMD="/usr/bin/pnpm i"
  _safety_interrupt_notice 2>&1
  exit 0
)" || true
if [[ "${_notice_out}" == *"[INT]"* && "${_notice_out}" == *"PM:"* && "${_notice_out}" == *"pnpm"*   && "${_notice_out}" == *"Projects/demo"* && "${_notice_out}" == *"Waiting for"* ]]; then
  ok "interrupt notice shows PM name + project + wait hint"
else
  bad "interrupt notice shows PM name + project + wait hint (out=${_notice_out})"
fi
# interrupt resolve before op_end in run_one
if grep -q 'Resolve interrupt BEFORE op_end' "${ROOT}/lib/backup/reinstall/run_one.sh"; then
  ok "run_one resolves interrupt before op_end (menu keeps Step/Item)"
else
  bad "run_one resolves interrupt before op_end (menu keeps Step/Item)"
fi
# Picker must expose numbered list + listing-policy note
if grep -q '_reinstall_picker_show_list' "${ROOT}/lib/backup/reinstall/select.sh"   && grep -q 'constraints_list_apply' "${ROOT}/lib/backup/reinstall/select.sh"   && grep -q -- '-F/--full' "${ROOT}/lib/backup/reinstall/select.sh"; then
  ok "picker shows numbered list under listing policy (-F/-T)"
else
  bad "picker shows numbered list under listing policy (-F/-T)"
fi
# Read-only node_modules checker exists
if [[ -x "${ROOT}/maintainer/temp/check-node-modules.sh" ]]   || [[ -f "${ROOT}/maintainer/temp/check-node-modules.sh" ]]; then
  ok "maintainer/temp/check-node-modules.sh present"
else
  bad "maintainer/temp/check-node-modules.sh present"
fi
# Phase 12b: picker undo/save_undo must not crash on full want-set (Kali e/i/p/f)
_nd_want=()
for _nd_i in 0 1 2 3 4; do _nd_want[$_nd_i]=1; done
_nd_want_undo=()
# replicate save_undo body without nameref locals
for _nd_k in "${!_nd_want[@]}"; do
  [[ -n "${_nd_k}" ]] && _nd_want_undo["${_nd_k}"]=1
done
_nd_want=()
for _nd_k in "${!_nd_want_undo[@]}"; do
  [[ -n "${_nd_k}" ]] && _nd_want["${_nd_k}"]=1
done
if [[ "${#_nd_want[@]}" -eq 5 && -n "${_nd_want[0]+x}" && -n "${_nd_want[4]+x}" ]]; then
  ok "picker undo/save_undo roundtrip on full want-set"
else
  bad "picker undo/save_undo roundtrip on full want-set (n=${#_nd_want[@]})"
fi
# No broken \${!arr[@]+word} expansions left in select.sh
if grep -qE '\$\{![a-z_]+\[@\]\+' "${ROOT}/lib/backup/reinstall/select.sh"; then
  bad "select.sh still has broken \${!arr[@]+word} expansions"
else
  ok "select.sh has no broken \${!arr[@]+word} expansions"
fi
# Phase 12: nested workspace members collapsed to root
_nd_rows_ws=(
  $'Workers/push	pnpm	-	pnpm i'
  $'Workers/push/apps/docs	pnpm	-	pnpm i'
  $'Workers/push/packages/core	pnpm	-	pnpm i'
  $'Projects/app	npm	-	npm i'
)
_nd_ws_out=()
# shellcheck source=/dev/null
source "${ROOT}/modules/node.sh"
node_filter_reinstall_rows _nd_rows_ws _nd_ws_out
if [[ "${#_nd_ws_out[@]}" -eq 2   && "${_nd_ws_out[0]}" == $'Workers/push\tpnpm\t-\tpnpm i'   && "${_nd_ws_out[1]}" == $'Projects/app\tnpm\t-\tnpm i' ]]; then
  ok "node_filter_reinstall_rows collapses nested workspace members"
else
  bad "node_filter_reinstall_rows collapses nested workspace members (n=${#_nd_ws_out[@]} rows=${_nd_ws_out[*]-})"
fi
# Phase 12: pnpm non-interactive allow-all-builds
_nd_pnpm_cmd="$(reinstall_pm_install_cmd pnpm "pnpm i")"
if [[ "${_nd_pnpm_cmd}" == *dangerouslyAllowAllBuilds* ]]; then
  ok "reinstall_pm_install_cmd adds pnpm allow-all-builds"
else
  bad "reinstall_pm_install_cmd adds pnpm allow-all-builds (${_nd_pnpm_cmd})"
fi
_nd_pnpm_cmd2="$(reinstall_pm_install_cmd pnpm "pnpm i --config.dangerouslyAllowAllBuilds=true")"
if [[ "${_nd_pnpm_cmd2}" == "pnpm i --config.dangerouslyAllowAllBuilds=true" ]]; then
  ok "reinstall_pm_install_cmd does not duplicate allow-all-builds"
else
  bad "reinstall_pm_install_cmd does not duplicate allow-all-builds (${_nd_pnpm_cmd2})"
fi
_nd_env2="$(reinstall_child_env_args | tr '\n' ' ')"
if [[ "${_nd_env2}" == *dangerously_allow_all_builds* ]]; then
  ok "reinstall_child_env_args sets allow-all-builds env"
else
  bad "reinstall_child_env_args sets allow-all-builds env (${_nd_env2})"
fi
# Phase 12: archive prefix detection + extract helper exist
if declare -F reinstall_archive_pkg_prefix >/dev/null 2>&1   && declare -F reinstall_extract_manifest >/dev/null 2>&1   && grep -q 'reinstall_extract_manifest' "${ROOT}/lib/cmd/restore.sh"; then
  ok "reinstall archive prefix + extract wired into restore"
else
  bad "reinstall archive prefix + extract wired into restore"
fi
# Build a tiny archive with ./packages prefix (pack layout) and extract
_nd_afx="$(mktemp "${TMPDIR:-/tmp}/linuxbkup-smoke-afx.XXXXXX.tar.zst")"
rm -f "${_nd_afx}"
_nd_astage="$(mktemp -d "${TMPDIR:-/tmp}/linuxbkup-smoke-astage.XXXXXX")"
mkdir -p "${_nd_astage}/packages"
printf '# kind\tpath\tpm\tlockfile\tcmd\nnode\tapp\tpnpm\t-\tpnpm i\n' \
  >"${_nd_astage}/packages/reinstalls.tsv"
tar -C "${_nd_astage}" -cf - . | zstd -q -o "${_nd_afx}"
_nd_pfx="$(reinstall_archive_pkg_prefix "${_nd_afx}")"
_nd_exd="$(mktemp -d "${TMPDIR:-/tmp}/linuxbkup-smoke-aex.XXXXXX")"
_nd_ex_rc=0
reinstall_extract_manifest "${_nd_afx}" "${_nd_exd}" || _nd_ex_rc=$?
if [[ "${_nd_ex_rc}" -eq 0 && -f "${_nd_exd}/packages/reinstalls.tsv" ]]; then
  ok "reinstall_extract_manifest handles ./packages archive prefix (pfx=${_nd_pfx})"
else
  bad "reinstall_extract_manifest handles ./packages archive prefix (rc=${_nd_ex_rc} pfx=${_nd_pfx})"
fi
rm -rf "${_nd_afx}" "${_nd_astage}" "${_nd_exd}"
# Phase 12: interrupt boundary helper
if declare -F reinstall_interrupt_boundary >/dev/null 2>&1   && declare -F reinstall_run_batch >/dev/null 2>&1   && grep -q 'REINSTALL_BATCH_IDX' "${ROOT}/lib/backup/reinstall/run.sh"; then
  ok "reinstall interrupt boundary + batch progress wired"
else
  bad "reinstall interrupt boundary + batch progress wired"
fi
# Phase 11: soft-quit during reinstall batch stops batch, does not exit 130
_nd_home4="$(mktemp -d "${TMPDIR:-/tmp}/linuxbkup-smoke-qhome.XXXXXX")"
_nd_shim4="$(mktemp -d "${TMPDIR:-/tmp}/linuxbkup-smoke-qshim.XXXXXX")"
_nd_fakeq="$(mktemp "${TMPDIR:-/tmp}/linuxbkup-smoke-qfake.XXXXXX")"
printf '#!/bin/sh\necho boom: ERR_TEST_FAIL >&2\nexit 1\n' >"${_nd_fakeq}"
chmod +x "${_nd_fakeq}"
ln -s "${_nd_fakeq}" "${_nd_shim4}/fakepm"
mkdir -p "${_nd_home4}/app-a"
printf '%s\n' '{"name":"a"}' >"${_nd_home4}/app-a/package.json"
# run_one handles RESULT=quit without process exit 130
_nd_q_probe="$(
  PATH="${_nd_shim4}:${PATH}" LINUXBKUP_YES=1 \
    bash -c '
      source "${LINUXBKUP_ROOT}/lib/backup/reinstall.sh"
      linuxbkup_without_monitor() {
        local _rc=0
        "$@"; _rc=$?
        LINUXBKUP_INTERRUPT_RESULT=quit
        LINUXBKUP_WAS_INTERRUPTED=1
        return "${_rc}"
      }
      set +e
      reinstall_run_one "'"${_nd_home4}"'" "app-a" "fakepm" "fakepm i"
      echo "RC=$?"
      echo "QUITFLAG=${REINSTALL_INTERRUPT_QUIT}"
      echo "REASON=${REINSTALL_LAST_REASON}"
      exit 0
    ' 2>&1
)" || true
if [[ "${_nd_q_probe}" == *RC=1* \
  && "${_nd_q_probe}" == *QUITFLAG=1* \
  && "${_nd_q_probe}" == *REASON=interrupted\ \(quit\)* ]]; then
  ok "reinstall soft-quit sets QUITFLAG + reason (no process exit)"
else
  bad "reinstall soft-quit sets QUITFLAG + reason (out=${_nd_q_probe})"
fi
# interrupt_apply soft-quit: RESULT=quit, no exit 130
_nd_soft_out="$(
  set +e
  source "${ROOT}/lib/core/common.sh"
  source "${ROOT}/lib/core/terminal/style.sh"
  source "${ROOT}/lib/core/interrupt.sh"
  LINUXBKUP_INTERRUPT_SOFT_QUIT=1
  LINUXBKUP_INTERRUPT_ACTION=quit
  LINUXBKUP_WAS_INTERRUPTED=1
  linuxbkup_interrupt_apply
  echo "RESULT=${LINUXBKUP_INTERRUPT_RESULT}"
  exit 0
)" || true
if [[ "${_nd_soft_out}" == *RESULT=quit* ]]; then
  ok "interrupt_apply soft-quit returns RESULT=quit (batch-safe)"
else
  bad "interrupt_apply soft-quit returns RESULT=quit (out=${_nd_soft_out})"
fi
# picker v2 mode strings present in select.sh
if grep -q '\[e\]xclude some' "${ROOT}/lib/backup/reinstall/select.sh" \
  && grep -q '\[i\]nclude only' "${ROOT}/lib/backup/reinstall/select.sh" \
  && grep -q '\[p\]M filter' "${ROOT}/lib/backup/reinstall/select.sh" \
  && grep -q 'reinstall_picker_apply_pm' "${ROOT}/lib/backup/reinstall/select.sh"; then
  ok "picker v2 modes wired in select.sh"
else
  bad "picker v2 modes wired in select.sh"
fi
# soft-quit + rerun helpers wired in run*.sh
if grep -q 'LINUXBKUP_INTERRUPT_SOFT_QUIT' "${ROOT}/lib/backup/reinstall/run_one.sh" \
  && grep -q 'reinstall_rerun_prompt' "${ROOT}/lib/backup/reinstall/run.sh" \
  && grep -q 'reinstall_summary_print' "${ROOT}/lib/backup/reinstall/run.sh"; then
  ok "reinstall batch soft-quit + failure re-run wired"
else
  bad "reinstall batch soft-quit + failure re-run wired"
fi
rm -rf "${_nd_home4}" "${_nd_shim4}" "${_nd_fakeq}"
# Workspace member detection + pnpm workspace error classify
_nd_ws="$(mktemp -d "${TMPDIR:-/tmp}/linuxbkup-smoke-ws.XXXXXX")"
mkdir -p "${_nd_ws}/packages/nodehunter" "${_nd_ws}/packages/docs"
printf '%s\n' '{"name":"nodehunter","workspaces":["packages/*"],"dependencies":{"@nodehunter/core":"workspace:*"}}' \
  >"${_nd_ws}/package.json"
printf '%s\n' '{"name":"@nodehunter/core"}' >"${_nd_ws}/packages/nodehunter/package.json"
printf '%s\n' '{"name":"@nodehunter/docs"}' >"${_nd_ws}/packages/docs/package.json"
printf 'packages:\n  - "packages/*"\n' >"${_nd_ws}/pnpm-workspace.yaml"
_nd_miss="$(reinstall_workspace_missing "${_nd_ws}" || true)"
if [[ -z "${_nd_miss}" ]]; then
  ok "reinstall_workspace_missing empty when members present"
else
  bad "reinstall_workspace_missing empty when members present (got ${_nd_miss})"
fi
rm -f "${_nd_ws}/packages/nodehunter/package.json"
_nd_miss="$(reinstall_workspace_missing "${_nd_ws}" || true)"
if [[ "${_nd_miss}" == *'@nodehunter/core'* ]]; then
  ok "reinstall_workspace_missing flags absent workspace member"
else
  bad "reinstall_workspace_missing flags absent workspace member (got ${_nd_miss})"
fi
_nd_wslog="$(mktemp "${TMPDIR:-/tmp}/linuxbkup-smoke-wslog.XXXXXX")"
cat >"${_nd_wslog}" <<'LOG'
Scope: all 3 workspace projects
ERR_PNPM_WORKSPACE_PKG_NOT_FOUND  In : "@nodehunter/core@workspace:*" is in the dependencies but no package named "@nodehunter/core" is present in the workspace
Packages found in the workspace: nodehunter, @nodehunter/docs
LOG
_nd_cls="$(reinstall_classify_fail "${_nd_wslog}" "${_nd_ws}")"
if [[ "${_nd_cls}" == *"workspace member missing"* && "${_nd_cls}" == *"@nodehunter/core"* ]]; then
  ok "reinstall_classify_fail names missing workspace member"
else
  bad "reinstall_classify_fail names missing workspace member (${_nd_cls})"
fi
# run_one skips workspace root when member package.json is gone
# (workspace root package.json at $_nd_ws; core package.json removed above)
set +e
PATH="${_nd_shim}:${PATH}" reinstall_run_one "${_nd_ws}" "." "pnpm" "pnpm i"
_nd_wsrc=$?
set -e
if [[ "${_nd_wsrc}" -eq 2 && "${REINSTALL_LAST_REASON}" == *"workspace sources missing"* ]]; then
  ok "reinstall_run_one skips incomplete workspace (missing member)"
else
  bad "reinstall_run_one skips incomplete workspace (rc=${_nd_wsrc} reason=${REINSTALL_LAST_REASON})"
fi
rm -rf "${_nd_home2}" "${_nd_shim}" "${_nd_fakepm}" "${_nd_ws}" "${_nd_wslog}" "${_nd_stage3}"
# Peek reinstalls.tsv from archive without full extract
_nd_arch="$(mktemp "${TMPDIR:-/tmp}/linuxbkup-smoke-ndarch.XXXXXX.tar.zst")"
rm -f "${_nd_arch}"
tar -C "${_nd_stage}" -cf - packages | zstd -q -o "${_nd_arch}"
_nd_peek=()
reinstall_peek_from_backup "${_nd_arch}" archive _nd_peek
if [[ "${#_nd_peek[@]}" -eq 3 ]]; then
  ok "reinstall_peek_from_backup reads tsv without full extract"
else
  bad "reinstall_peek_from_backup reads tsv without full extract (n=${#_nd_peek[@]})"
fi
_nd_pf_out=""
_nd_pf_rc=0
set +e
_nd_pf_out="$(LINUXBKUP_YES=1 reinstall_preflight_guide "${_nd_arch}" archive 2>&1)"
_nd_pf_rc=$?
set -e
if [[ "${_nd_pf_rc}" -eq 0 && "${_nd_pf_out}" == *"Reinstall preflight"* ]]; then
  ok "reinstall_preflight_guide under -y (no hang)"
else
  bad "reinstall_preflight_guide under -y (rc=${_nd_pf_rc})"
fi
# Windows/interop PM shims must not count as ready
# shellcheck source=/dev/null
source "${ROOT}/lib/core/platform/detect.sh"
if platform_path_is_windows_interop "/mnt/d/Tools/Global/pnpm/bin/pnpm" \
  && platform_path_is_windows_interop "/mnt/d/Tools/NodeJS/npm" \
  && platform_path_is_windows_interop "/mnt/c/Windows/System32/cmd.exe" \
  && ! platform_path_is_windows_interop "/usr/bin/pnpm"; then
  ok "platform_path_is_windows_interop flags /mnt/* paths"
else
  bad "platform_path_is_windows_interop flags /mnt/* paths"
fi
# .exe-only PATH entry must not resolve as a Linux PM
_fake_win_dir="$(mktemp -d "${TMPDIR:-/tmp}/linuxbkup-smoke-winbin.XXXXXX")"
printf '#!/bin/sh\necho win-pnpm\n' >"${_fake_win_dir}/pnpm.exe"
chmod +x "${_fake_win_dir}/pnpm.exe"
_nd_res="$(PATH="${_fake_win_dir}:${PATH}" platform_linux_command pnpm 2>/dev/null || true)"
if [[ -z "${_nd_res}" || "${_nd_res}" != "${_fake_win_dir}"/* ]]; then
  ok "platform_linux_command skips .exe-only pnpm shims"
else
  bad "platform_linux_command must not accept .exe pnpm (got ${_nd_res})"
fi
# PM status line includes resolved path for ready PMs
_nd_st="$(reinstall_pm_status_line bash "$((5))")"
if [[ "${_nd_st}" == $'ready\tbash\t'* ]]; then
  ok "reinstall_pm_status_line lists ready PM with resolved path"
else
  bad "reinstall_pm_status_line lists ready PM with resolved path (${_nd_st})"
fi
# List policy: 12 fake ready lines → show top 10
# shellcheck source=/dev/null
source "${ROOT}/lib/constraints/list.sh"
ND_LIST_LINES=()
for _nd_i in $(seq 1 12); do
  ND_LIST_LINES+=("  ✓ tool${_nd_i}  →  /usr/bin/tool${_nd_i}")
done
_nd_plimit_out="$(printf '%s\n' "${ND_LIST_LINES[@]}" | constraints_list_apply 2>/dev/null)" || true
_nd_plimit_n="$(printf '%s\n' "${_nd_plimit_out}" | grep -c 'tool' || true)"
if [[ "${_nd_plimit_n}" -eq 10 ]]; then
  ok "list policy auto-truncates >10 items to top 10"
else
  bad "list policy auto-truncates >10 items to top 10 (n=${_nd_plimit_n})"
fi
# --ask wins over --yes (profile precedence)
# shellcheck source=/dev/null
source "${ROOT}/lib/core/profile.sh"
LINUXBKUP_YES=1 LINUXBKUP_ASK=1
linuxbkup_apply_ask_yes_precedence 2>/dev/null || true
if [[ "${LINUXBKUP_YES}" -eq 0 && "${LINUXBKUP_ASK}" -eq 1 ]]; then
  ok "--ask precedence clears --yes"
else
  bad "--ask precedence clears --yes (yes=${LINUXBKUP_YES} ask=${LINUXBKUP_ASK})"
fi
rm -rf "${_nd_home}" "${_nd_stage}" "${_nd_arch}" "${_fake_win_dir}"
unset LINUXBKUP_ASK LINUXBKUP_YES

# sudo → SUDO_USER (not root) for target user
# shellcheck source=/dev/null
source "${ROOT}/lib/env/users.sh"
_sudo_u="$(
  unset LINUXBKUP_USER
  SUDO_USER="smokeuser"
  # non-root euid: SUDO_USER must be ignored (USER left as real login)
  env_resolve_user
)"
if [[ "${_sudo_u}" == "$(id -un)" ]]; then
  ok "env_resolve_user ignores SUDO_USER when not root"
else
  bad "env_resolve_user ignores SUDO_USER when not root (got ${_sudo_u})"
fi
if grep -q 'SUDO_USER' "${ROOT}/lib/env/users.sh" \
  && grep -q 'env_sudo_user_remap' "${ROOT}/lib/env/users.sh" \
  && grep -q 'restore_files_chown_args' "${ROOT}/lib/backup/restore_files.sh" \
  && grep -q 'refusing to restore home/secrets into /root' "${ROOT}/lib/backup/restore_files.sh"; then
  ok "sudo restore targets SUDO_USER + chown + /root guard"
else
  bad "sudo restore targets SUDO_USER + chown + /root guard"
fi

# Home/config restore: rsync staged trees; --force-overwrite for conflicts
LINUXBKUP_ROOT="${ROOT}"
export LINUXBKUP_ROOT
# shellcheck source=/dev/null
source "${ROOT}/lib/core/terminal/style.sh"
# shellcheck source=/dev/null
source "${ROOT}/lib/core/safety.sh"
# shellcheck source=/dev/null
source "${ROOT}/lib/backup/restore_files.sh"
_rf_stage="$(mktemp -d "${TMPDIR:-/tmp}/linuxbkup-smoke-rf.XXXXXX")"
_rf_dest="$(mktemp -d "${TMPDIR:-/tmp}/linuxbkup-smoke-rfd.XXXXXX")"
mkdir -p "${_rf_stage}/home/dot" "${_rf_stage}/secrets/.ssh" "${_rf_stage}/config/etc"
printf 'home-a\n' >"${_rf_stage}/home/dot/a.txt"
printf 'sec-k\n' >"${_rf_stage}/secrets/.ssh/id_test"
printf 'etc-x\n' >"${_rf_stage}/config/etc/linuxbkup-smoke.conf"
# First apply into empty dest (no -f needed)
LINUXBKUP_FORCE_OVERWRITE=0
LINUXBKUP_DRY_RUN=0
if restore_files_copy_tree "${_rf_stage}/home" "${_rf_dest}" "home" \
  && [[ -f "${_rf_dest}/dot/a.txt" ]] \
  && grep -q 'home-a' "${_rf_dest}/dot/a.txt"; then
  ok "restore home tree into empty dest"
else
  bad "restore home tree into empty dest"
fi
# Conflict without -f must refuse
printf 'old\n' >"${_rf_dest}/dot/a.txt"
_rf_err="$(restore_files_copy_tree "${_rf_stage}/home" "${_rf_dest}" "home" 2>&1)" && _rf_rc=0 || _rf_rc=$?
if [[ "${_rf_rc}" -ne 0 && "${_rf_err}" == *"force-overwrite"* ]]; then
  ok "restore refuses overwrite without --force-overwrite"
else
  bad "restore refuses overwrite without --force-overwrite (rc=${_rf_rc})"
fi
# With -f, overwrite + secrets merge
LINUXBKUP_FORCE_OVERWRITE=1
if restore_files_apply "${_rf_stage}" "${_rf_dest}" \
  && grep -q 'home-a' "${_rf_dest}/dot/a.txt" \
  && [[ -f "${_rf_dest}/.ssh/id_test" ]] \
  && grep -q 'sec-k' "${_rf_dest}/.ssh/id_test"; then
  ok "restore -f applies home + secrets into dest"
else
  bad "restore -f applies home + secrets into dest"
fi
unset LINUXBKUP_FORCE_OVERWRITE
rm -rf "${_rf_stage}" "${_rf_dest}"
if grep -q 'restore_files_apply' "${ROOT}/lib/cmd/restore.sh" \
  && grep -q 'files — home' "${ROOT}/lib/cmd/restore.sh"; then
  ok "restore cmd wires home/config files step"
else
  bad "restore cmd wires home/config files step"
fi

help04="$("${CLI}" --no-color --help 2>/dev/null)" || true
if [[ "${help04}" == *"--reclaim"* && "${help04}" == *"--mark-secret"* ]]; then
  ok "help lists reclaim/mark-secret"
else
  bad "help lists reclaim/mark-secret"
fi

# Help: separate rows + short aliases (not combined "--keep-stage / --stage-dir")
help_rows="$("${CLI}" --no-color --help 2>/dev/null)" || true
if [[ "${help_rows}" == *"-k, --keep-stage"* && "${help_rows}" == *"-S, --stage-dir"* \
  && "${help_rows}" == *"-i, --include"* && "${help_rows}" == *"-e, --exclude"* \
  && "${help_rows}" != *"--keep-stage / --stage-dir"* \
  && "${help_rows}" != *"--include/--exclude"* ]]; then
  ok "help separate rows + short aliases for stage/include"
else
  bad "help separate rows + short aliases for stage/include"
fi
help_backup="$("${CLI}" --no-color help backup 2>/dev/null)" || true
if [[ "${help_backup}" == *"-k, --keep-stage"* && "${help_backup}" == *"-S, --stage-dir"* \
  && "${help_backup}" == *"-i, --include"* && "${help_backup}" == *"--no-gitignore"* ]]; then
  ok "backup help lists stage/include/gitignore separately"
else
  bad "backup help lists stage/include/gitignore separately"
fi

# Short aliases parse
alias_parse="$("${CLI}" --no-color -n -k -S /tmp -i Projects -e Product -m 2G -j plan 2>&1)" || true
if [[ "${alias_parse}" != *"unknown option"* && "${alias_parse}" != *"requires"* ]]; then
  ok "short aliases -n/-k/-S/-i/-e/-m/-j parse"
else
  bad "short aliases -n/-k/-S/-i/-e/-m/-j parse"
fi

# Reclaim: no circular nameref warning
reclaim_err="$( (
  # shellcheck source=/dev/null
  source "${ROOT}/lib/backup/reclaim.sh"
  scan_rows=("${fake_home}/.cache"$'\t'"skip"$'\t'"skip"$'\t'"1M"$'\t'"regenerable")
  cands=()
  backup_reclaim_candidates scan_rows cands
) 2>&1 )" || true
if [[ "${reclaim_err}" != *"circular name reference"* ]]; then
  ok "reclaim has no circular nameref"
else
  bad "reclaim has no circular nameref"
fi

# Gitignore filter on by default; --no-gitignore bypasses
# shellcheck source=/dev/null
source "${ROOT}/lib/constraints/base.sh"
# shellcheck source=/dev/null
source "${ROOT}/lib/backup/home.sh"
LINUXBKUP_NO_GITIGNORE=0
backup_plan_excludes
backup_rsync_args
rsync_joined="${BACKUP_RSYNC_ARGS[*]}"
if [[ "${rsync_joined}" == *":- .gitignore"* && "${rsync_joined}" == *"node_modules"* ]]; then
  ok "rsync args include gitignore filter + node_modules"
else
  bad "rsync args include gitignore filter + node_modules"
fi
LINUXBKUP_NO_GITIGNORE=1
backup_rsync_args
rsync_joined="${BACKUP_RSYNC_ARGS[*]}"
if [[ "${rsync_joined}" != *":- .gitignore"* ]]; then
  ok "--no-gitignore omits gitignore filter"
else
  bad "--no-gitignore omits gitignore filter"
fi
unset LINUXBKUP_NO_GITIGNORE

# 08.8 snapshot on backup dry-run
snap_out="$("${CLI}" --no-color -y -n --no-secrets backup 2>/dev/null)" || true
if [[ "${snap_out}" == *"Environment snapshot"* && "${snap_out}" == *"Package managers"* ]]; then
  ok "backup dry-run prints environment snapshot"
else
  bad "backup dry-run prints environment snapshot"
fi
# 09.4–09.5 preflight banner + structured step labels
if [[ "${snap_out}" == *"Preflight"* \
  && "${snap_out}" == *"Gitignore"* \
  && "${snap_out}" == *"Max size"* \
  && "${snap_out}" == *"Profile"* \
  && "${snap_out}" == *"Step 1/7"* \
  && "${snap_out}" == *"preflight"* \
  && "${snap_out}" == *"Step 2/7"* \
  && "${snap_out}" == *"detect"* ]]; then
  ok "backup preflight banner + ui_step labels (09.4–09.5)"
else
  bad "backup preflight banner + ui_step labels (09.4–09.5)"
fi
# 08.10 structured events → jsonl
# shellcheck source=/dev/null
source "${ROOT}/lib/core/terminal/events.sh"
_evf="$(mktemp "${TMPDIR:-/tmp}/linuxbkup-smoke-ev.XXXXXX")"
linuxbkup_events_begin "${_evf}"
linuxbkup_event start preflight "n=1" "total=7"
linuxbkup_event ok preflight
linuxbkup_events_end
if [[ -f "${_evf}" ]] \
  && grep -q '"event":"step"' "${_evf}" \
  && grep -q '"phase":"start"' "${_evf}" \
  && grep -q '"step":"preflight"' "${_evf}" \
  && grep -q '"phase":"ok"' "${_evf}" \
  && grep -q 'ui_step_event' "${ROOT}/lib/cmd/backup.sh" \
  && grep -q 'events.jsonl' "${ROOT}/lib/cmd/backup.sh" \
  && grep -q 'events_detach_file' "${ROOT}/lib/cmd/backup.sh" \
  && grep -q "metadata/events.jsonl" "${ROOT}/lib/archive/checksums.sh"; then
  ok "structured step events write jsonl (08.10)"
else
  bad "structured step events write jsonl (08.10)"
fi
rm -f "${_evf}"
# events.jsonl mismatch must not fail verify (telemetry drift)
# shellcheck source=/dev/null
source "${ROOT}/lib/archive/verify.sh"
_ev_stage="$(mktemp -d "${TMPDIR:-/tmp}/linuxbkup-smoke-evck.XXXXXX")"
mkdir -p "${_ev_stage}/metadata" "${_ev_stage}/home"
printf 'payload\n' >"${_ev_stage}/home/a.txt"
printf 'line1\n' >"${_ev_stage}/metadata/events.jsonl"
(
  cd "${_ev_stage}" && find . -type f ! -name checksums.sha256 -printf '%P\n' | sort | xargs -r sha256sum
) >"${_ev_stage}/checksums.sha256"
printf 'line1\nline2-mutated\n' >"${_ev_stage}/metadata/events.jsonl"
_ev_vfy="$(archive_verify_checksums_inplace "${_ev_stage}" 2>&1)" && _ev_vfy_rc=0 || _ev_vfy_rc=$?
if [[ "${_ev_vfy_rc}" -eq 0 && "${_ev_vfy}" == *"events.jsonl checksum drift"* ]]; then
  ok "verify soft-warns events.jsonl drift (payload still hard-fail)"
else
  bad "verify soft-warns events.jsonl drift (rc=${_ev_vfy_rc})"
fi
rm -rf "${_ev_stage}"
# shellcheck source=/dev/null
source "${ROOT}/lib/core/terminal/style.sh"
if declare -F ui_step >/dev/null && declare -F backup_preflight_banner >/dev/null 2>&1; then
  ok "ui_step + backup_preflight_banner defined"
else
  # backup_preflight_banner lives in preflight.sh
  # shellcheck source=/dev/null
  source "${ROOT}/lib/backup/preflight.sh"
  if declare -F ui_step >/dev/null && declare -F backup_preflight_banner >/dev/null; then
    ok "ui_step + backup_preflight_banner defined"
  else
    bad "ui_step + backup_preflight_banner defined"
  fi
fi

# 09.1 secrets fail-fast before copy (--yes, secrets present, no pass)
# shellcheck source=/dev/null
source "${ROOT}/lib/backup/preflight.sh"
sec_home="$(mktemp -d "${TMPDIR:-/tmp}/linuxbkup-smoke-secpre.XXXXXX")"
mkdir -p "${sec_home}/.ssh"
printf 'k\n' >"${sec_home}/.ssh/id_test"
LINUXBKUP_HOME="${sec_home}"
LINUXBKUP_YES=1
LINUXBKUP_NO_SECRETS=0
LINUXBKUP_SECRETS_PLAIN=0
unset LINUXBKUP_SECRETS_PASS LINUXBKUP_SECRETS_PASS_FILE LINUXBKUP_SECRETS_MODE
pre_err="$(backup_secrets_preflight "${sec_home}" 2>&1)" && pre_rc=0 || pre_rc=$?
if [[ "${pre_rc}" -ne 0 && "${pre_err}" == *"fail-fast"* ]]; then
  ok "secrets preflight fails fast under --yes without pass"
else
  bad "secrets preflight fails fast under --yes without pass"
fi
# CLI path: must die before staging created
cli_sec_err="$("${CLI}" --no-color -y backup 2>&1)" && cli_sec_rc=0 || cli_sec_rc=$?
if [[ "${cli_sec_rc}" -ne 0 && "${cli_sec_err}" == *"fail-fast"* && "${cli_sec_err}" != *"Copying into staging"* ]]; then
  ok "backup -y without pass fatals before copy"
else
  bad "backup -y without pass fatals before copy"
fi
rm -rf "${sec_home}"
unset LINUXBKUP_HOME LINUXBKUP_YES LINUXBKUP_SECRETS_MODE

# Regenerable filter: Python venv + __pycache__ + .pyc
# shellcheck source=/dev/null
source "${ROOT}/lib/fs/sizes.sh"
py_tree="$(mktemp -d "${TMPDIR:-/tmp}/linuxbkup-smoke-py.XXXXXX")"
mkdir -p "${py_tree}/app" "${py_tree}/venv/lib/python3.12/site-packages/x" "${py_tree}/app/__pycache__"
dd if=/dev/zero of="${py_tree}/venv/lib/python3.12/site-packages/x/big.bin" bs=1024 count=800 status=none 2>/dev/null \
  || dd if=/dev/zero of="${py_tree}/venv/lib/python3.12/site-packages/x/big.bin" bs=1024 count=800 2>/dev/null
printf 'code\n' >"${py_tree}/app/main.py"
printf 'cache\n' >"${py_tree}/app/__pycache__/main.cpython-312.pyc"
printf 'loose\n' >"${py_tree}/app/orphan.pyc"
raw_py="$(fs_dir_bytes "${py_tree}")"
filt_py="$(fs_du_bytes "${py_tree}" filtered)"
if [[ "${filt_py}" -lt "${raw_py}" && "${filt_py}" -lt 5000 ]]; then
  ok "python filter strips venv/__pycache__/.pyc (raw=${raw_py} filt=${filt_py})"
else
  bad "python filter strips venv/__pycache__/.pyc (raw=${raw_py} filt=${filt_py})"
fi
# Optional live tree: ~/Bots when present
if [[ -d "${HOME}/Bots" ]]; then
  bots_raw="$(fs_dir_bytes "${HOME}/Bots")"
  bots_filt="$(fs_du_bytes "${HOME}/Bots" filtered)"
  if [[ "${bots_filt}" -lt "${bots_raw}" ]]; then
    ok "~/Bots filtered smaller than raw (${bots_filt} < ${bots_raw})"
  else
    bad "~/Bots filtered smaller than raw (${bots_filt} < ${bots_raw})"
  fi
fi
rm -rf "${py_tree}"

# File exclude globs present
if [[ "${CONSTRAINTS_FILE_EXCLUDE_GLOBS[*]}" == *'*.pyc'* && "${CONSTRAINTS_DU_EXCLUDE_GLOBS[*]}" == *'__pycache__'* \
  && "${CONSTRAINTS_DU_EXCLUDE_GLOBS[*]}" == *'.wrangler'* ]]; then
  ok "regenerable lists include pycache/pyc/wrangler"
else
  bad "regenerable lists include pycache/pyc/wrangler"
fi

# 05.2 space helper loadable
if declare -F backup_space_preflight >/dev/null && declare -F platform_fs_avail_bytes >/dev/null; then
  ok "space preflight helpers loadable"
else
  bad "space preflight helpers loadable"
fi

# .tmp + mise installs stripped from filter stack
tmp_tree="$(mktemp -d "${TMPDIR:-/tmp}/linuxbkup-smoke-tmp.XXXXXX")"
mkdir -p "${tmp_tree}/.codex/.tmp" "${tmp_tree}/keep" \
  "${tmp_tree}/.local/share/mise/installs/node/v1" \
  "${tmp_tree}/.local/share/mise/migrations" \
  "${tmp_tree}/.asdf/installs/nodejs/20.0.0" \
  "${tmp_tree}/.nvm/versions/node/v20.0.0"
dd if=/dev/zero of="${tmp_tree}/.codex/.tmp/junk.bin" bs=1024 count=400 status=none 2>/dev/null \
  || dd if=/dev/zero of="${tmp_tree}/.codex/.tmp/junk.bin" bs=1024 count=400 2>/dev/null
dd if=/dev/zero of="${tmp_tree}/.local/share/mise/installs/node/v1/big.bin" bs=1024 count=800 status=none 2>/dev/null \
  || dd if=/dev/zero of="${tmp_tree}/.local/share/mise/installs/node/v1/big.bin" bs=1024 count=800 2>/dev/null
dd if=/dev/zero of="${tmp_tree}/.asdf/installs/nodejs/20.0.0/big.bin" bs=1024 count=400 status=none 2>/dev/null \
  || dd if=/dev/zero of="${tmp_tree}/.asdf/installs/nodejs/20.0.0/big.bin" bs=1024 count=400 2>/dev/null
dd if=/dev/zero of="${tmp_tree}/.nvm/versions/node/v20.0.0/big.bin" bs=1024 count=400 status=none 2>/dev/null \
  || dd if=/dev/zero of="${tmp_tree}/.nvm/versions/node/v20.0.0/big.bin" bs=1024 count=400 2>/dev/null
printf 'ok\n' >"${tmp_tree}/keep/a.txt"
printf 'm\n' >"${tmp_tree}/.local/share/mise/migrations/x"
raw_t="$(fs_dir_bytes "${tmp_tree}")"
filt_t="$(fs_du_bytes "${tmp_tree}" filtered)"
if [[ "${filt_t}" -lt 50000 && "${filt_t}" -lt "${raw_t}" ]]; then
  ok ".tmp and mise/asdf/nvm installs stripped from du filter"
else
  bad ".tmp and mise/asdf/nvm installs stripped from du filter (raw=${raw_t} filt=${filt_t})"
fi
rm -rf "${tmp_tree}"

# 05.3 schema writer
# shellcheck source=/dev/null
source "${ROOT}/lib/backup/schema.sh"
sch_stage="$(mktemp -d "${TMPDIR:-/tmp}/linuxbkup-smoke-schema.XXXXXX")"
mkdir -p "${sch_stage}/metadata"
LINUXBKUP_DRY_RUN=0
LINUXBKUP_SECRETS_MODE=exclude
backup_write_schema "${sch_stage}" "smoke" "${sch_stage}" || true
if [[ -f "${sch_stage}/metadata/schema.json" ]] \
  && grep -q 'linuxbkup.schema/v1' "${sch_stage}/metadata/schema.json" \
  && grep -q 'schema_version' "${sch_stage}/metadata/schema.json"; then
  ok "schema.json written with version fields"
else
  bad "schema.json written with version fields"
fi
# decisions helper path
printf '%s\n' $'/tmp/x\tinclude\tinclude\t1\treason' | backup_write_decisions "${sch_stage}"
if [[ -f "${sch_stage}/metadata/decisions.tsv" ]] && grep -q '^path' "${sch_stage}/metadata/decisions.tsv"; then
  ok "decisions.tsv writer works"
else
  bad "decisions.tsv writer works"
fi
rm -rf "${sch_stage}"

# phase 10 standing research doc exists
if [[ -f "${ROOT}/maintainer/phases/10-pm-tools-research.md" ]] \
  && grep -q 'OPEN' "${ROOT}/maintainer/phases/10-pm-tools-research.md"; then
  ok "phase 10 PM/tools research doc present"
else
  bad "phase 10 PM/tools research doc present"
fi

# Workers policy + parallel checksums
export LINUXBKUP_ROOT="${ROOT}"
# shellcheck source=/dev/null
source "${ROOT}/lib/core/common.sh"
# shellcheck source=/dev/null
source "${ROOT}/lib/core/terminal/style.sh"
# shellcheck source=/dev/null
source "${ROOT}/lib/core/terminal/control.sh"
# shellcheck source=/dev/null
source "${ROOT}/lib/core/terminal/progress.sh"
# shellcheck source=/dev/null
source "${ROOT}/lib/core/workers.sh"
_ui_init
LINUXBKUP_WORKERS=4
linuxbkup_workers_init
w1="$(linuxbkup_workers_for 5)"
w2="$(linuxbkup_workers_for 40)"
w3="$(linuxbkup_workers_for 500)"
if [[ "${w1}" -eq 1 && "${w2}" -eq 2 && "${w3}" -eq 4 ]]; then
  ok "workers_for scales 1/2/4 by count"
else
  bad "workers_for scales 1/2/4 by count (got ${w1}/${w2}/${w3})"
fi
help_w="$("${CLI}" --no-color --help 2>/dev/null)" || true
if [[ "${help_w}" == *"-w, --workers"* ]]; then
  ok "help lists -w/--workers"
else
  bad "help lists -w/--workers"
fi
# shellcheck source=/dev/null
source "${ROOT}/lib/archive/checksums.sh"
ck_stage="$(mktemp -d "${TMPDIR:-/tmp}/linuxbkup-smoke-ck.XXXXXX")"
mkdir -p "${ck_stage}/home/a"
for i in $(seq 1 40); do
  printf 'blob-%s\n' "${i}" >"${ck_stage}/home/a/f${i}.txt"
done
LINUXBKUP_DRY_RUN=0
LINUXBKUP_WORKERS=4
linuxbkup_workers_init
archive_write_checksums "${ck_stage}"
ck_n="$(wc -l <"${ck_stage}/checksums.sha256" | tr -d ' ')"
if [[ "${ck_n}" -eq 40 ]] && (cd "${ck_stage}" && sha256sum -c checksums.sha256 --quiet); then
  ok "parallel checksums write+verify 40 files"
else
  bad "parallel checksums write+verify 40 files (n=${ck_n})"
fi
if [[ -f "${ROOT}/lib/archive/_checksum_worker.sh" ]] \
  && grep -q 'set +m' "${ROOT}/lib/archive/checksums.sh" \
  && grep -q '_checksum_kill_workers' "${ROOT}/lib/archive/checksums.sh"; then
  ok "checksum workers isolated (no set -m INT dump)"
else
  bad "checksum workers isolated (no set -m INT dump)"
fi
# parallel verify path
# shellcheck source=/dev/null
source "${ROOT}/lib/archive/verify.sh"
if archive_verify_checksums_inplace "${ck_stage}"; then
  ok "parallel verify checksums inplace"
else
  bad "parallel verify checksums inplace"
fi
rm -rf "${ck_stage}"

# compat probes
# shellcheck source=/dev/null
source "${ROOT}/lib/tools/compat.sh"
if tools_compat_tar_zstd && tools_compat_rsync && tools_compat_sha256sum; then
  ok "compat tar_zstd/rsync/sha256sum probes"
else
  bad "compat tar_zstd/rsync/sha256sum probes"
fi
# workers_for pack/du
wp="$(linuxbkup_workers_for 1 pack)"
wd="$(linuxbkup_workers_for 10 du)"
if [[ "${wp}" -eq 4 && "${wd}" -ge 2 ]]; then
  ok "workers_for pack/du rules"
else
  bad "workers_for pack/du rules (pack=${wp} du=${wd})"
fi

# trap helpers exist
# shellcheck source=/dev/null
source "${ROOT}/lib/core/safety.sh"
if declare -F safety_on_int >/dev/null && declare -F safety_on_tstp >/dev/null; then
  ok "signal handlers safety_on_int/tstp defined"
else
  bad "signal handlers safety_on_int/tstp defined"
fi
# Ctrl+Z = monitor mode + STOP process group (not child-only wedge)
if declare -F safety_on_cont >/dev/null \
  && grep -q 'set -m' "${ROOT}/lib/core/safety.sh" \
  && grep -q 'kill -STOP 0' "${ROOT}/lib/core/safety.sh"; then
  ok "Ctrl+Z monitor mode + STOP process group"
else
  bad "Ctrl+Z monitor mode + STOP process group"
fi
# Live progress parks before logs (stderr \r/EL2 pattern)
# shellcheck source=/dev/null
source "${ROOT}/lib/core/terminal/control.sh"
if declare -F term_live_park >/dev/null && declare -F term_clear_line >/dev/null \
  && grep -q 'set +e' "${ROOT}/linuxbkup"; then
  ok "live-line park + set +e around commands"
else
  bad "live-line park + set +e around commands"
fi
if declare -F linuxbkup_tty_restore >/dev/null \
  && grep -q 'tput cnorm' "${ROOT}/lib/core/terminal/control.sh"; then
  ok "tty restore uses tput cnorm"
else
  bad "tty restore uses tput cnorm"
fi
if grep -q 'linuxbkup_without_monitor' "${ROOT}/lib/archive/pack.sh" \
  && grep -q 'interrupt_pending' "${ROOT}/lib/archive/pack.sh" \
  && grep -qE 'pack_rc.*141|141.*pack_rc' "${ROOT}/lib/archive/pack.sh"; then
  ok "pack step has interrupt retry path"
else
  bad "pack step has interrupt retry path"
fi
# INT ignored during teardown/resume so set -m re-raise cannot kill mid-retry
if grep -q 'linuxbkup_interrupt_disarm' "${ROOT}/lib/core/interrupt.sh" \
  && grep -q 'trap '\'''\'' INT' "${ROOT}/lib/core/safety.sh"; then
  ok "interrupt disarm during teardown/resume"
else
  bad "interrupt disarm during teardown/resume"
fi
# Solid proof: SIGINT during without_monitor → menu (test reply) → retry → survive
# (Pack failure mode: set -m gave tar|zstd its own PGID so bash never got the trap.)
_proof_out="$(
  set +e
  # shellcheck source=/dev/null
  source "${ROOT}/lib/core/common.sh"
  # shellcheck source=/dev/null
  source "${ROOT}/lib/core/terminal/style.sh"
  # shellcheck source=/dev/null
  source "${ROOT}/lib/core/safety.sh"
  _ui_init
  linuxbkup_install_traps
  LINUXBKUP_TEST_INTERRUPT_REPLY=r
  export LINUXBKUP_TEST_INTERRUPT_REPLY
  linuxbkup_op_begin "pack" "/tmp/linuxbkup-smoke-pack" 0 1
  _proof_pid="${BASHPID}"
  (
    sleep 0.25
    kill -INT "${_proof_pid}"
  ) &
  linuxbkup_without_monitor sleep 8
  if ! linuxbkup_interrupt_pending && [[ -z "${LINUXBKUP_INTERRUPT_ACTION:-}" ]]; then
    echo "PROOF_FAIL: no interrupt pending" >&2
    exit 1
  fi
  linuxbkup_interrupt_resolve
  if [[ "${LINUXBKUP_INTERRUPT_RESULT}" != "retry" ]]; then
    echo "PROOF_FAIL: RESULT='${LINUXBKUP_INTERRUPT_RESULT}'" >&2
    exit 1
  fi
  linuxbkup_interrupt_arm
  echo PROOF_OK
  exit 0
)"
_proof_rc=$?
if [[ "${_proof_rc}" -eq 0 && "${_proof_out}" == *PROOF_OK* ]]; then
  ok "SIGINT proof: without_monitor + menu reply retry survives"
else
  bad "SIGINT proof: without_monitor + menu reply retry survives (rc=${_proof_rc} out=${_proof_out})"
fi
# backup keeps INT through summary; pack/rsync use without_monitor
if grep -q "trap 'linuxbkup_tty_restore' EXIT" "${ROOT}/lib/cmd/backup.sh" \
  && grep -q 'without_monitor' "${ROOT}/lib/core/safety.sh" \
  && grep -q 'op_begin "index"' "${ROOT}/lib/cmd/backup.sh" \
  && grep -q 'op_begin "secrets"' "${ROOT}/lib/cmd/backup.sh"; then
  ok "backup steps wired for interrupt (secrets/index/summary/rsync/pack)"
else
  bad "backup steps wired for interrupt (secrets/index/summary/rsync/pack)"
fi
# interrupt UX (Ctrl+C menu)
if declare -F linuxbkup_interrupt_menu >/dev/null \
  && declare -F linuxbkup_interrupt_apply >/dev/null \
  && declare -F linuxbkup_interrupt_resolve >/dev/null \
  && declare -F linuxbkup_op_begin >/dev/null \
  && declare -F linuxbkup_interrupt_pending >/dev/null; then
  ok "interrupt menu/op state helpers defined"
else
  bad "interrupt menu/op state helpers defined"
fi
# apply must clear flags in-process (never via $(apply) subshell)
LINUXBKUP_INTERRUPT_ACTION="skip"
LINUXBKUP_WAS_INTERRUPTED=1
linuxbkup_interrupt_apply
if [[ -z "${LINUXBKUP_INTERRUPT_ACTION}" && "${LINUXBKUP_WAS_INTERRUPTED}" -eq 0 \
  && "${LINUXBKUP_INTERRUPT_RESULT}" == "skip" ]]; then
  ok "interrupt apply clears parent shell flags"
else
  bad "interrupt apply clears parent shell flags (action='${LINUXBKUP_INTERRUPT_ACTION}' was=${LINUXBKUP_WAS_INTERRUPTED} result='${LINUXBKUP_INTERRUPT_RESULT}')"
fi
if ! grep -qE '\$\(linuxbkup_interrupt_apply\)' "${ROOT}/lib"/cmd/*.sh "${ROOT}/lib"/backup/*.sh "${ROOT}/lib"/archive/*.sh "${ROOT}/lib"/classify/*.sh 2>/dev/null; then
  ok "no \$(interrupt_apply) subshell call sites"
else
  bad "no \$(interrupt_apply) subshell call sites"
fi
# rsync rc=20 is interrupt, not soft-skip (function comment + return path)
if grep -q 'return 20' "${ROOT}/lib/core/safety.sh" \
  && grep -qE 'rc.*-eq 20|SIGINT' "${ROOT}/lib/core/safety.sh"; then
  ok "rsync SIGINT (rc=20) treated as interrupt"
else
  bad "rsync SIGINT (rc=20) treated as interrupt"
fi

rm -rf "${fake_home}"

exit "${fail}"
