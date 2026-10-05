# shellcheck shell=bash
# Node project discovery → packages/reinstalls.json (+ .tsv for bash restore).

# Escape a string for JSON (no newlines).
_node_json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/ }"
  s="${s//$'\t'/ }"
  printf '%s' "${s}"
}

# Detect pm for a directory with package.json. Prints: pm<TAB>lockfile<TAB>cmd
node_detect_pm() {
  local dir="$1"
  local pkg="${dir}/package.json"
  local pm="" lock="" cmd="" field=""

  if [[ -f "${pkg}" ]]; then
    field="$(grep -oE '"packageManager"[[:space:]]*:[[:space:]]*"[^"]+"' "${pkg}" 2>/dev/null \
      | head -n1 | sed -E 's/.*"packageManager"[[:space:]]*:[[:space:]]*"([^@"]+).*/\1/' || true)"
    case "${field}" in
      npm|pnpm|yarn|bun) pm="${field}" ;;
    esac
  fi

  if [[ -z "${pm}" ]]; then
    if [[ -f "${dir}/pnpm-lock.yaml" ]]; then
      pm="pnpm"
    elif [[ -f "${dir}/package-lock.json" ]]; then
      pm="npm"
    elif [[ -f "${dir}/yarn.lock" ]]; then
      pm="yarn"
    elif [[ -f "${dir}/bun.lockb" || -f "${dir}/bun.lock" ]]; then
      pm="bun"
    else
      pm="pnpm"
    fi
  fi

  case "${pm}" in
    pnpm)
      lock="pnpm-lock.yaml"
      [[ -f "${dir}/${lock}" ]] || lock="-"
      cmd="pnpm i"
      ;;
    npm)
      lock="package-lock.json"
      if [[ -f "${dir}/${lock}" ]]; then
        cmd="npm ci"
      else
        lock="-"
        cmd="npm i"
      fi
      ;;
    yarn)
      lock="yarn.lock"
      [[ -f "${dir}/${lock}" ]] || lock="-"
      cmd="yarn install"
      ;;
    bun)
      if [[ -f "${dir}/bun.lockb" ]]; then
        lock="bun.lockb"
      elif [[ -f "${dir}/bun.lock" ]]; then
        lock="bun.lock"
      else
        lock="-"
      fi
      cmd="bun install"
      ;;
    *)
      pm="pnpm"
      lock="-"
      cmd="pnpm i"
      ;;
  esac

  printf '%s\t%s\t%s\n' "${pm}" "${lock}" "${cmd}"
}

# Scan stage/home (or a home tree) for package.json roots.
# Args: root_dir — directory that contains project trees (usually stage/home)
# Fills nameref array with lines: rel_path<TAB>pm<TAB>lockfile<TAB>cmd
node_scan_projects() {
  local root="$1"
  local -n _out="$2"
  local pkg dir rel pm lock cmd

  _out=()
  [[ -d "${root}" ]] || return 0

  while IFS= read -r -d '' pkg; do
    dir="$(dirname -- "${pkg}")"
    # Skip nested package.json under node_modules
    case "${dir}" in
      */node_modules|*/node_modules/*) continue ;;
    esac
    rel="${dir#"${root}"/}"
    [[ "${rel}" == "${dir}" ]] && continue
    [[ -z "${rel}" ]] && continue
    IFS=$'\t' read -r pm lock cmd < <(node_detect_pm "${dir}") || true
    [[ -n "${pm}" ]] || continue
    _out+=("${rel}"$'\t'"${pm}"$'\t'"${lock}"$'\t'"${cmd}")
  done < <(find "${root}" -type f -name package.json \
    ! -path '*/node_modules/*' -print0 2>/dev/null || true)
}

# Write packages/reinstalls.json + packages/reinstalls.tsv from staged home/.
# Args: stage
node_capture_manifests() {
  local stage="$1"
  local home_tree="${stage}/home"
  local pkg_dir="${stage}/packages"
  local -a rows=()
  local n=0 i rel pm lock cmd first=1 jlock=""

  if [[ "${LINUXBKUP_DRY_RUN:-0}" -eq 1 ]]; then
    log_info "dry-run — would scan for Node projects → packages/reinstalls.json"
    return 0
  fi

  if [[ ! -d "${home_tree}" ]]; then
    log_verbose "no staged home/ — skip node reinstalls capture"
    return 0
  fi

  node_scan_projects "${home_tree}" rows
  n="${#rows[@]}"
  mkdir -p "${pkg_dir}"

  {
    printf '# kind\tpath\tpm\tlockfile\tcmd\n'
    for ((i = 0; i < n; i++)); do
      IFS=$'\t' read -r rel pm lock cmd <<<"${rows[i]}" || true
      printf 'node\t%s\t%s\t%s\t%s\n' "${rel}" "${pm}" "${lock}" "${cmd}"
    done
  } >"${pkg_dir}/reinstalls.tsv"

  {
    printf '{\n  "schema": "linuxbkup.reinstalls/v1",\n  "node": [\n'
    first=1
    for ((i = 0; i < n; i++)); do
      IFS=$'\t' read -r rel pm lock cmd <<<"${rows[i]}" || true
      if [[ "${first}" -eq 1 ]]; then
        first=0
      else
        printf ',\n'
      fi
      # JSON uses empty lockfile string when sentinel "-"
      jlock="${lock}"
      [[ "${jlock}" == "-" ]] && jlock=""
      printf '    {"path":"%s","pm":"%s","lockfile":"%s","cmd":"%s"}' \
        "$(_node_json_escape "${rel}")" \
        "$(_node_json_escape "${pm}")" \
        "$(_node_json_escape "${jlock}")" \
        "$(_node_json_escape "${cmd}")"
    done
    printf '\n  ]\n}\n'
  } >"${pkg_dir}/reinstalls.json"

  if [[ "${n}" -gt 0 ]]; then
    log_ok "node reinstalls: ${n} project(s) → packages/reinstalls.json"
  else
    log_verbose "node reinstalls: no package.json projects found"
  fi
  return 0
}
