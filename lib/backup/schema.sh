# shellcheck shell=bash
# Restore contract: schema.json + decisions.tsv (phase 05.3).

LINUXBKUP_SCHEMA_VERSION="${LINUXBKUP_SCHEMA_VERSION:-1}"

# Write metadata/schema.json. Args: stage user home
backup_write_schema() {
  local stage="$1" user="$2" home="$3"
  local meta="${stage}/metadata"
  local out="${meta}/schema.json"
  local created distro_id distro_ver arch wsl pretty hostname
  local secrets_mode gitignore_on apt_on

  if [[ "${LINUXBKUP_DRY_RUN:-0}" -eq 1 ]]; then
    log_info "dry-run — would write schema.json"
    return 0
  fi

  mkdir -p "${meta}"
  created="$(date -Iseconds 2>/dev/null || date)"
  hostname="$(hostname 2>/dev/null || printf 'unknown')"

  # shellcheck source=lib/env/distro.sh
  source "${LINUXBKUP_ROOT}/lib/env/distro.sh"
  pretty="$(env_distro_pretty)"
  distro_id="$(env_distro_id)"
  distro_ver="$(env_distro_version_id)"
  arch="$(env_arch)"
  wsl="$(env_wsl_kind)"

  secrets_mode="${LINUXBKUP_SECRETS_MODE:-unknown}"
  gitignore_on=true
  [[ "${LINUXBKUP_NO_GITIGNORE:-0}" -eq 1 ]] && gitignore_on=false
  apt_on=false
  linuxbkup_require_cmd apt-mark dpkg && apt_on=true

  # Minimal JSON (no jq). Escape is best-effort for path/host fields.
  _schema_esc() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    printf '%s' "${s}"
  }

  {
    printf '{\n'
    printf '  "schema": "linuxbkup.schema/v1",\n'
    printf '  "schema_version": %s,\n' "${LINUXBKUP_SCHEMA_VERSION}"
    printf '  "tool_version": "%s",\n' "$(_schema_esc "${LINUXBKUP_VERSION}")"
    printf '  "created": "%s",\n' "$(_schema_esc "${created}")"
    printf '  "profile": "%s",\n' "$(_schema_esc "${LINUXBKUP_PROFILE:-balanced}")"
    printf '  "user": "%s",\n' "$(_schema_esc "${user}")"
    printf '  "home": "%s",\n' "$(_schema_esc "${home}")"
    printf '  "host": {\n'
    printf '    "hostname": "%s",\n' "$(_schema_esc "${hostname}")"
    printf '    "pretty": "%s",\n' "$(_schema_esc "${pretty}")"
    printf '    "distro_id": "%s",\n' "$(_schema_esc "${distro_id}")"
    printf '    "version_id": "%s",\n' "$(_schema_esc "${distro_ver}")"
    printf '    "arch": "%s",\n' "$(_schema_esc "${arch}")"
    printf '    "wsl": "%s"\n' "$(_schema_esc "${wsl}")"
    printf '  },\n'
    printf '  "features": {\n'
    printf '    "secrets_mode": "%s",\n' "$(_schema_esc "${secrets_mode}")"
    printf '    "gitignore": %s,\n' "${gitignore_on}"
    printf '    "apt_manual": %s,\n' "${apt_on}"
    printf '    "regenerable_filter": true,\n'
    printf '    "space_preflight": true\n'
    printf '  }\n'
    printf '}\n'
  } >"${out}"

  log_ok "schema.json written"
  ui_kv_path "Schema" "${out}"
}

# Write decisions.tsv from classify-style rows.
# Args: stage; rows on stdin as path<TAB>class<TAB>action<TAB>size<TAB>reason
# Final column decision = include|skip|secret|ask (normalized).
backup_write_decisions() {
  local stage="$1"
  local out="${stage}/metadata/decisions.tsv"
  local path class action size reason decision

  if [[ "${LINUXBKUP_DRY_RUN:-0}" -eq 1 ]]; then
    log_info "dry-run — would write decisions.tsv"
    return 0
  fi

  mkdir -p "${stage}/metadata"
  {
    printf 'path\tclass\taction\tsize\treason\tdecision\n'
    while IFS=$'\t' read -r path class action size reason; do
      [[ -z "${path:-}" ]] && continue
      decision="${action}"
      case "${action}" in
        include|skip|ask) ;;
        *) decision="skip" ;;
      esac
      if [[ "${class}" == "secret" && "${LINUXBKUP_NO_SECRETS:-0}" -eq 1 ]]; then
        decision="skip"
      elif [[ "${class}" == "secret" ]]; then
        decision="secret"
      fi
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
        "${path}" "${class}" "${action}" "${size:-}" "${reason:-}" "${decision}"
    done
  } >"${out}"

  log_ok "decisions.tsv written"
  ui_kv_path "Decisions" "${out}"
}
