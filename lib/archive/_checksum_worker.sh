#!/usr/bin/env bash
# shellcheck shell=bash
# Checksum worker script (not an inline function — avoids job-control dumps).
# Args: partfile outfile donefile failedfile
set +e
part="${1:?}"
out="${2:?}"
donef="${3:?}"
failed="${4:?}"

batch=32
buf=()
flush() {
  local x j
  [[ "${#buf[@]}" -eq 0 ]] && return 0
  if ! sha256sum -- "${buf[@]}" >>"${out}" 2>/dev/null; then
    for x in "${buf[@]}"; do
      if ! sha256sum -- "${x}" >>"${out}" 2>/dev/null; then
        printf '%s\n' "${x}" >>"${failed}"
      fi
    done
  fi
  for ((j = 0; j < ${#buf[@]}; j++)); do
    printf '\n' >>"${donef}"
  done
  buf=()
}

while IFS= read -r f || [[ -n "${f}" ]]; do
  [[ -z "${f}" ]] && continue
  buf+=("${f}")
  if [[ "${#buf[@]}" -ge "${batch}" ]]; then
    flush
  fi
done <"${part}"
flush
exit 0
