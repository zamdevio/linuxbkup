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

  # Prefer mode resolved at preflight (fail-fast); otherwise resolve now.
  mode="${LINUXBKUP_SECRETS_MODE:-}"
  if [[ -z "${mode}" || "${mode}" == "none" ]]; then
    # Secrets appeared after preflight (e.g. --mark-secret / nested .env)
    mode="$(backup_secrets_resolve_mode)" || return 1
  fi
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

# Resolve passphrase for decrypt (env/file/TTY). Prints nothing; sets LINUXBKUP_SECRETS_PASS.
# Returns 1 if unavailable.
_backup_secrets_pass_for_decrypt() {
  if [[ -n "${LINUXBKUP_SECRETS_PASS_FILE:-}" && -r "${LINUXBKUP_SECRETS_PASS_FILE}" ]]; then
    LINUXBKUP_SECRETS_PASS="$(<"${LINUXBKUP_SECRETS_PASS_FILE}")"
    export LINUXBKUP_SECRETS_PASS
  fi
  if [[ -n "${LINUXBKUP_SECRETS_PASS:-}" ]]; then
    return 0
  fi
  if [[ "${LINUXBKUP_YES:-0}" -eq 1 ]]; then
    log_fatal "decrypt needs LINUXBKUP_SECRETS_PASS or LINUXBKUP_SECRETS_PASS_FILE"
    return 1
  fi
  if [[ ! -t 0 && ! -c /dev/tty ]]; then
    log_fatal "non-TTY decrypt needs LINUXBKUP_SECRETS_PASS(_FILE)"
    return 1
  fi
  local p
  if [[ -c /dev/tty ]]; then
    read -r -s -p "Secrets passphrase (decrypt): " p </dev/tty
    printf '\n' >/dev/tty
  else
    read -r -s -p "Secrets passphrase (decrypt): " p
    printf '\n'
  fi
  if [[ -z "${p}" ]]; then
    log_fatal "empty passphrase"
    return 1
  fi
  LINUXBKUP_SECRETS_PASS="${p}"
  export LINUXBKUP_SECRETS_PASS
  return 0
}

# Decrypt secrets.tar.age from a stage/extract root into dest_dir (creates secrets/).
# Args: root [dest_dir] — dest defaults to root/secrets
# No-op (return 0) when plaintext secrets/ already present or nothing encrypted.
# Returns 0 ok, 1 hard fail, 2 skipped (no encrypted blob / excluded).
backup_secrets_decrypt_stage() {
  local root="$1"
  local dest="${2:-${root}/secrets}"
  local envf="${root}/metadata/secrets.env"
  local blob="${root}/secrets.tar.age"
  local keyenc="${root}/secrets.agekey.enc"
  local key err encrypted=""

  if [[ -d "${root}/secrets" ]] && [[ -n "$(find "${root}/secrets" -type f -print -quit 2>/dev/null || true)" ]]; then
    log_info "secrets/ already plaintext under root — skip decrypt"
    return 2
  fi
  if [[ ! -f "${blob}" || ! -f "${keyenc}" ]]; then
    log_verbose "no secrets.tar.age — nothing to decrypt"
    return 2
  fi

  if [[ -f "${envf}" ]]; then
    encrypted="$(awk -F= '/^encrypted=/{print $2; exit}' "${envf}" | tr -d '\r')"
  fi
  if [[ "${encrypted}" == "false" ]]; then
    log_warn "secrets.env says encrypted=false but blob present — attempting decrypt anyway"
  fi

  if [[ "${LINUXBKUP_DRY_RUN:-0}" -eq 1 ]]; then
    log_info "dry-run — would decrypt ${blob} → ${dest}/"
    return 0
  fi

  if ! linuxbkup_require_cmd age openssl tar; then
    log_fatal "age, openssl, tar required to decrypt secrets"
    return 1
  fi
  if ! _backup_secrets_pass_for_decrypt; then
    return 1
  fi

  if [[ -e "${dest}" && "${LINUXBKUP_FORCE_OVERWRITE:-0}" -ne 1 ]]; then
    log_fatal "refusing to write ${dest} — pass --force-overwrite if intentional"
    return 1
  fi

  key="${TMPDIR:-/tmp}/linuxbkup-agekey-dec.$$.$RANDOM"
  err="${TMPDIR:-/tmp}/linuxbkup-agedec-err.$$.$RANDOM"
  rm -f "${key}" "${err}"

  if declare -F term_progress_status >/dev/null 2>&1; then
    term_progress_status "Decrypting secrets with age…"
  else
    log_info "Decrypting secrets with age…"
  fi

  if ! openssl enc -d -aes-256-cbc -pbkdf2 \
    -pass "pass:${LINUXBKUP_SECRETS_PASS}" \
    -in "${keyenc}" -out "${key}" 2>"${err}"; then
    declare -F term_progress_end >/dev/null 2>&1 && term_progress_end
    log_fatal "openssl unwrap of age identity failed (wrong passphrase?)"
    [[ -s "${err}" ]] && log_verbose "$(head -n 3 "${err}")"
    rm -f "${key}" "${err}"
    unset LINUXBKUP_SECRETS_PASS
    return 1
  fi
  rm -f "${err}"

  rm -rf "${dest}"
  mkdir -p "${dest}"
  # blob is age(tar of secrets/); extract so dest gets .ssh/… (strip secrets/ prefix)
  if ! age -d -i "${key}" -o - "${blob}" 2>/dev/null \
    | tar -C "${dest}" --strip-components=1 -xf - 2>/dev/null; then
    # Fallback: extract with secrets/ prefix then move
    rm -rf "${dest}"
    mkdir -p "${dest}.__unwrap"
    if age -d -i "${key}" -o - "${blob}" | tar -C "${dest}.__unwrap" -xf -; then
      if [[ -d "${dest}.__unwrap/secrets" ]]; then
        mv "${dest}.__unwrap/secrets" "${dest}"
        rm -rf "${dest}.__unwrap"
      else
        mv "${dest}.__unwrap" "${dest}"
      fi
    else
      declare -F term_progress_end >/dev/null 2>&1 && term_progress_end
      rm -f "${key}"
      rm -rf "${dest}" "${dest}.__unwrap"
      unset LINUXBKUP_SECRETS_PASS
      log_fatal "age decrypt / tar extract of secrets failed"
      return 1
    fi
  fi
  rm -f "${key}"
  unset LINUXBKUP_SECRETS_PASS
  declare -F term_progress_end >/dev/null 2>&1 && term_progress_end
  log_ok "secrets decrypted → ${dest}"
  return 0
}
