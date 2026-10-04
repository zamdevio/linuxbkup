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
if [[ "${help_out}" == *"Commands"* && "${help_out}" == *"inspect"* && "${help_out}" == *"deps"* ]]; then
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

bak_out="$(env LINUXBKUP_YES=1 "${CLI}" --no-color --dry-run -o /tmp/linuxbkup-smoke-dry.tar.zst backup 2>/dev/null)" || true
if [[ "${bak_out}" == *"dry-run"* && "${bak_out}" == *"Backup plan"* ]]; then
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

# Portable allowlists: no host-shaped project dirnames in shipped defaults
# shellcheck source=/dev/null
source "${ROOT}/lib/constraints/base.sh"
# shellcheck source=/dev/null
source "${ROOT}/lib/constraints/backup_paths.sh"
joined="${CONSTRAINTS_BACKUP_DIRS[*]} ${CONSTRAINTS_IMPORTANT_TARGETS[*]}"
if [[ "${joined}" == *Projects* || "${joined}" == *Workers* || "${joined}" == *Tools* ]]; then
  bad "portable: no host-shaped dirnames in backup/important lists"
else
  ok "portable: no host-shaped dirnames in backup/important lists"
fi

# Filter stack produces du --exclude args
excl=()
constraints_du_exclude_args excl
if [[ "${#excl[@]}" -ge 3 && "${excl[*]}" == *node_modules* ]]; then
  ok "filter stack: du excludes regenerables"
else
  bad "filter stack: du excludes regenerables"
fi

exit "${fail}"
