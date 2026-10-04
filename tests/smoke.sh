#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="${ROOT}/wslbkup"
fail=0

ok() { printf 'OK  %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

if "${CLI}" --help >/dev/null; then ok "help exits 0"; else bad "help exits 0"; fi

ver="$("${CLI}" --version)"
if [[ "${ver}" == *dev* || "${ver}" == *0.* ]]; then ok "version prints"; else bad "version prints (${ver})"; fi

if "${CLI}" inspect >/dev/null; then ok "inspect stubs"; else bad "inspect stubs"; fi

if "${CLI}" nope >/dev/null 2>&1; then bad "unknown command should fail"; else ok "unknown command fails"; fi

if "${CLI}" restore >/dev/null 2>&1; then bad "restore without arg should fail"; else ok "restore without arg fails"; fi

if bash -n "${CLI}" && bash -n "${ROOT}"/lib/core/*.sh && bash -n "${ROOT}"/lib/cmd/*.sh; then
  ok "bash -n syntax"
else
  bad "bash -n syntax"
fi

exit "${fail}"
