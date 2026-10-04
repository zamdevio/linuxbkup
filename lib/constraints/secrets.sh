# shellcheck shell=bash
# Sensitive path templates + EREs. Presence only — never print file contents.

CONSTRAINTS_SECRETS_TARGETS=(
  .ssh
  .gnupg
  .aws
  .netrc
  .npmrc
  .docker/config.json
)

CONSTRAINTS_SECRETS_REGEXES=(
  '/\.ssh(/|$)'
  '/\.gnupg(/|$)'
  '/\.aws(/|$)'
  '/\.config/gcloud(/|$)'
  '/\.docker/config\.json$'
  '/\.netrc$'
  '/\.npmrc$'
  '(^|/)id_(rsa|ed25519|ecdsa)$'
  '(^|/)credentials\.json$'
  '(^|/)\.credentials$'
  '(^|/)secrets\.ya?ml$'
  '(^|/)\.env(\.|$)'
)

# Basenames for shallow find during inspect
CONSTRAINTS_SECRETS_FIND_NAMES=(
  .env
  .env.local
  credentials.json
)
