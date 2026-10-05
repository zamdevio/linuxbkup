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

# True if relative path is tooling/noise (not a real app to reinstall).
node_path_is_noise() {
  local rel="$1"
  case "${rel}" in
    .claude|.claude/*|.var|.var/*|.cursor|.cursor/*|.agents|.agents/*)
      return 0
      ;;
    */wailsjs|*/wailsjs/*)
      return 0
      ;;
    */fixtures/*|*/fixture/*|*/__fixtures__/*)
      return 0
      ;;
    */node_modules|*/node_modules/*)
      return 0
      ;;
    */.yarn/*|*/.pnpm/*)
      return 0
      ;;
  esac
  return 1
}

# True if dir has a node lockfile at this level.
node_dir_has_lockfile() {
  local dir="$1"
  [[ -f "${dir}/pnpm-lock.yaml" \
    || -f "${dir}/package-lock.json" \
    || -f "${dir}/yarn.lock" \
    || -f "${dir}/bun.lockb" \
    || -f "${dir}/bun.lock" ]]
}

# True if package.json looks like a workspace root.
node_dir_is_workspace_root() {
  local dir="$1"
  local pkg="${dir}/package.json"
  [[ -f "${dir}/pnpm-workspace.yaml" || -f "${dir}/pnpm-workspace.yml" ]] && return 0
  [[ -f "${pkg}" ]] || return 1
  grep -qE '"workspaces"[[:space:]]*:' "${pkg}" 2>/dev/null
}

# Walk up from dir toward stop (home root); print nearest workspace root, or empty.
node_find_workspace_root() {
  local dir="$1"
  local stop="$2"
  local cur="${dir}"
  while [[ -n "${cur}" && "${cur}" != "/" ]]; do
    case "${cur}" in
      "${stop}"|"${stop}"/*) ;;
      *) return 1 ;;
    esac
    if node_dir_is_workspace_root "${cur}"; then
      printf '%s\n' "${cur}"
      return 0
    fi
    [[ "${cur}" == "${stop}" ]] && break
    cur="$(dirname -- "${cur}")"
  done
  return 1
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

# Scan stage/home for install roots (workspace roots or dirs with their own lockfile).
# Fills nameref: rel_path<TAB>pm<TAB>lockfile<TAB>cmd
node_scan_projects() {
  local root="$1"
  local -n _out="$2"
  local pkg dir rel pm lock cmd ws abs
  local -A seen=()

  _out=()
  [[ -d "${root}" ]] || return 0

  while IFS= read -r -d '' pkg; do
    dir="$(dirname -- "${pkg}")"
    case "${dir}" in
      */node_modules|*/node_modules/*) continue ;;
    esac
    rel="${dir#"${root}"/}"
    [[ "${rel}" == "${dir}" || -z "${rel}" ]] && continue
    if node_path_is_noise "${rel}"; then
      continue
    fi

    # Prefer workspace root over every nested package.json
    if ws="$(node_find_workspace_root "${dir}" "${root}")"; then
      abs="${ws}"
      rel="${abs#"${root}"/}"
    else
      # Standalone: only if this directory has its own lockfile
      if ! node_dir_has_lockfile "${dir}"; then
        continue
      fi
      abs="${dir}"
    fi

    [[ -n "${seen[${rel}]+x}" ]] && continue
    seen["${rel}"]=1

    IFS=$'\t' read -r pm lock cmd < <(node_detect_pm "${abs}") || true
    [[ -n "${pm}" ]] || continue
    _out+=("${rel}"$'\t'"${pm}"$'\t'"${lock}"$'\t'"${cmd}")
  done < <(find "${root}" -type f -name package.json \
    ! -path '*/node_modules/*' -print0 2>/dev/null || true)
}

# Filter rows (path pm lock cmd) — drop noise; used on restore for older fat manifests.
node_filter_reinstall_rows() {
  local -n _in="$1"
  local -n _out="$2"
  local path pm lock cmd
  _out=()
  for row in "${_in[@]+"${_in[@]}"}"; do
    IFS=$'\t' read -r path pm lock cmd <<<"${row}" || true
    node_path_is_noise "${path}" && continue
    _out+=("${row}")
  done
}

# Write packages/reinstalls.json + packages/reinstalls.tsv from staged home/.
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
