# shellcheck shell=bash
# Encrypt staged secrets/ with age; wipe plaintext after success.
#
# Layout after encrypt:
#   secrets.tar.age     — age ciphertext (recipient = ephemeral X25519)
#   secrets.agekey.enc  — age identity wrapped with openssl (passphrase)
#   metadata/secrets.env

# Resolve passphrase source. Prints mode: exclude|plain|encrypt
backup_secrets_resolve_mode() {
  if [[ "${LINUXBKUP_NO_SECRETS:-0}" -eq 1 ]]; then
    printf '%s\n' "exclude"
    return 0
  fi
  if [[ "${LINUXBKUP_SECRETS_PLAIN:-0}" -eq 1 ]]; then
    printf '%s\n' "plain"
    return 0
  fi
  if [[ -n "${LINUXBKUP_SECRETS_PASS_FILE:-}" && -r "${LINUXBKUP_SECRETS_PASS_FILE}" ]]; then
    LINUXBKUP_SECRETS_PASS="$(<"${LINUXBKUP_SECRETS_PASS_FILE}")"
    export LINUXBKUP_SECRETS_PASS
  fi
  if [[ -n "${LINUXBKUP_SECRETS_PASS:-}" ]]; then
    printf '%s\n' "encrypt"
    return 0
  fi
  if [[ "${LINUXBKUP_YES:-0}" -eq 1 ]]; then
    log_fatal "secrets present: set LINUXBKUP_SECRETS_PASS or LINUXBKUP_SECRETS_PASS_FILE, or pass --secrets-plain / --no-secrets"
    return 1
  fi
  if [[ ! -t 0 && ! -c /dev/tty ]]; then
    log_fatal "non-TTY secrets encrypt needs LINUXBKUP_SECRETS_PASS(_FILE) or --secrets-plain / --no-secrets"
    return 1
  fi
  local p1 p2
  if [[ -c /dev/tty ]]; then
    read -r -s -p "Secrets passphrase (age): " p1 </dev/tty
    printf '\n' >/dev/tty
    read -r -s -p "Confirm passphrase: " p2 </dev/tty
    printf '\n' >/dev/tty
  else
    read -r -s -p "Secrets passphrase (age): " p1
    printf '\n'
    read -r -s -p "Confirm passphrase: " p2
    printf '\n'
  fi
  if [[ -z "${p1}" || "${p1}" != "${p2}" ]]; then
    log_fatal "passphrase empty or mismatch"
    return 1
  fi
  LINUXBKUP_SECRETS_PASS="${p1}"
  export LINUXBKUP_SECRETS_PASS
  printf '%s\n' "encrypt"
}

# Encrypt tar stream to age recipient; wrap identity with openssl (passphrase).
_backup_age_encrypt_tar() {
  local stage="$1" out="$2" keyenc="$3" pass="$4"
  local key pub err

  if ! linuxbkup_require_cmd age age-keygen tar openssl; then
    log_fatal "age, age-keygen, tar, openssl required to encrypt secrets"
    return 1
  fi

  # age-keygen refuses to overwrite — path must not exist yet
  key="${TMPDIR:-/tmp}/linuxbkup-agekey.$$.$RANDOM"
  err="${TMPDIR:-/tmp}/linuxbkup-ageerr.$$.$RANDOM"
  rm -f "${key}" "${err}"
  # age-keygen prints "Public key: …" on stderr; identity file also has "# public key: …"
  if ! age-keygen -o "${key}" 2>"${err}"; then
    log_fatal "age-keygen failed"
    cat "${err}" >&2 || true
    rm -f "${key}" "${err}"
    return 1
  fi
  pub="$(awk '/^Public key:/{print $3; exit}' "${err}")"
  rm -f "${err}"
  if [[ -z "${pub}" ]]; then
    pub="$(awk '/^# public key:/{print $4; exit}' "${key}")"
  fi
  if [[ -z "${pub}" ]]; then
    log_fatal "could not read age public key"
    rm -f "${key}"
    return 1
  fi

  if ! tar -C "${stage}" -cf - secrets | age -r "${pub}" -o "${out}"; then
    rm -f "${key}" "${out}"
    log_fatal "age encrypt of secrets tar failed"
    return 1
  fi

  if ! openssl enc -aes-256-cbc -pbkdf2 -salt \
    -pass "pass:${pass}" \
    -in "${key}" -out "${keyenc}"; then
    rm -f "${key}" "${out}" "${keyenc}"
    log_fatal "openssl wrap of age identity failed"
    return 1
  fi
  rm -f "${key}"
  return 0
}

# Encrypt stage/secrets → stage/secrets.tar.age and remove plaintext tree.
backup_secrets_encrypt_stage() {
  local stage="$1"
  local sec="${stage}/secrets"
  local out="${stage}/secrets.tar.age"
  local keyenc="${stage}/secrets.agekey.enc"
  local mode

  [[ -d "${sec}" ]] || {
    log_verbose "no secrets/ staging dir — skip encrypt"
    return 0
  }
  if [[ -z "$(find "${sec}" -type f -print -quit 2>/dev/null || true)" ]]; then
    log_verbose "secrets/ empty — skip encrypt"
    return 0
  fi

  if [[ "${LINUXBKUP_DRY_RUN:-0}" -eq 1 ]]; then
    log_info "dry-run — would age-encrypt secrets/"
    return 0
  fi

  mode="$(backup_secrets_resolve_mode)" || return 1
  case "${mode}" in
    exclude)
      rm -rf "${sec}"
      log_info "secrets excluded from archive"
      return 0
      ;;
    plain)
      mkdir -p "${stage}/metadata"
      printf 'encrypted=false\n' >"${stage}/metadata/secrets.env"
      log_warn "secrets left plaintext (--secrets-plain)"
      return 0
      ;;
    encrypt) ;;
    *)
      log_fatal "unknown secrets mode: ${mode}"
      return 1
      ;;
  esac

  if declare -F term_progress_status >/dev/null 2>&1; then
    term_progress_status "Encrypting secrets with age…"
  else
    log_info "Encrypting secrets with age…"
  fi
  if ! _backup_age_encrypt_tar "${stage}" "${out}" "${keyenc}" "${LINUXBKUP_SECRETS_PASS}"; then
    declare -F term_progress_end >/dev/null 2>&1 && term_progress_end
    return 1
  fi
  rm -rf "${sec}"
  mkdir -p "${stage}/metadata"
  {
    printf 'encrypted=true\n'
    printf 'cipher=age-x25519+openssl-keywrap\n'
    printf 'blob=secrets.tar.age\n'
    printf 'key=secrets.agekey.enc\n'
  } >"${stage}/metadata/secrets.env"
  unset LINUXBKUP_SECRETS_PASS
  declare -F term_progress_end >/dev/null 2>&1 && term_progress_end
  log_ok "secrets encrypted → secrets.tar.age"
}
