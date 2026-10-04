#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="${ROOT}/wslbkup"
fail=0

ok() { printf 'OK  %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

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

if "${CLI}" --no-color help deps >/dev/null 2>&1; then ok "help deps"; else bad "help deps"; fi

out="$(env WSLBKUP_INSPECT_QUICK=1 "${CLI}" --no-color --no-links inspect 2>/dev/null)" || true
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

if env WSLBKUP_TEST=1 "${CLI}" --no-color nope >/dev/null 2>&1; then
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
  && bash -n "${ROOT}"/lib/cmd/*.sh \
  && bash -n "${ROOT}"/lib/env/*.sh \
  && bash -n "${ROOT}"/lib/fs/*.sh \
  && bash -n "${ROOT}"/lib/windows/*.sh \
  && bash -n "${ROOT}"/lib/classify/*.sh \
  && bash -n "${ROOT}"/lib/constraints/*.sh \
  && bash -n "${ROOT}"/lib/tools/*.sh; then
  ok "bash -n syntax"
else
  bad "bash -n syntax"
fi

exit "${fail}"
