#!/usr/bin/env bash
# shellcheck shell=bash
# Checksum worker script (not an inline function — avoids job-control dumps).
# Args: partfile outfile donefile failedfile
# Honors LINUXBKUP_COMPAT_SHA_TOOL (sha256sum|shasum|openssl) from parent.
set +e
part="${1:?}"
out="${2:?}"
donef="${3:?}"
failed="${4:?}"

_sha_tool="${LINUXBKUP_COMPAT_SHA_TOOL:-}"
if [[ -z "${_sha_tool}" ]]; then
  if command -v sha256sum >/dev/null 2>&1; then _sha_tool=sha256sum
  elif command -v shasum >/dev/null 2>&1; then _sha_tool=shasum
  elif command -v openssl >/dev/null 2>&1; then _sha_tool=openssl
  fi
fi

_hash_batch() {
  case "${_sha_tool}" in
    sha256sum) sha256sum -- "$@" 2>/dev/null ;;
    shasum) shasum -a 256 -- "$@" 2>/dev/null ;;
    openssl)
      local x h
      for x in "$@"; do
        h="$(openssl dgst -sha256 -- "${x}" 2>/dev/null | awk '{print $NF}')"
        [[ -n "${h}" ]] && printf '%s  %s\n' "${h}" "${x}"
      done
      ;;
    *) return 1 ;;
  esac
}

batch=32
buf=()
flush() {
  local x j
  [[ "${#buf[@]}" -eq 0 ]] && return 0
  if ! _hash_batch "${buf[@]}" >>"${out}"; then
    for x in "${buf[@]}"; do
      if ! _hash_batch "${x}" >>"${out}"; then
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
