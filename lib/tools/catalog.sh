# shellcheck shell=bash
# Known dependency catalog (tools with guides/tools/<name>.guide).

# Core tools needed for backup/restore path.
LINUXBKUP_DEPS_CORE=(
  du
  find
  tar
  zstd
  rsync
  sha256sum
)

# Nice-to-have / feature-gated.
LINUXBKUP_DEPS_OPTIONAL=(
  age
  timeout
  numfmt
  realpath
  fzf
)

# All deps that have (or should have) a guide — union of core + optional + any extra guides.
tools_catalog_all() {
  local t f base
  local -A seen=()

  for t in "${LINUXBKUP_DEPS_CORE[@]}" "${LINUXBKUP_DEPS_OPTIONAL[@]}"; do
    seen["${t}"]=1
    printf '%s\n' "${t}"
  done

  if [[ -d "$(tools_guides_dir)" ]]; then
    for f in "$(tools_guides_dir)"/*.guide; do
      [[ -e "${f}" ]] || continue
      base="$(basename "${f}" .guide)"
      [[ -n "${seen[${base}]+x}" ]] && continue
      seen["${base}"]=1
      printf '%s\n' "${base}"
    done
  fi
}

tools_dep_tier() {
  local tool="$1" t
  for t in "${LINUXBKUP_DEPS_CORE[@]}"; do
    [[ "${t}" == "${tool}" ]] && { printf '%s\n' "core"; return 0; }
  done
  for t in "${LINUXBKUP_DEPS_OPTIONAL[@]}"; do
    [[ "${t}" == "${tool}" ]] && { printf '%s\n' "optional"; return 0; }
  done
  printf '%s\n' "extra"
}

# Resolve install command string for current package family (empty if unknown).
tools_install_command() {
  local tool="$1" family how
  family="$(tools_pkg_family)"
  case "${family}" in
    apt) how="$(tools_guide_get "${tool}" "HOW_APT" || true)" ;;
    dnf) how="$(tools_guide_get "${tool}" "HOW_DNF" || true)" ;;
    yum) how="$(tools_guide_get "${tool}" "HOW_YUM" || tools_guide_get "${tool}" "HOW_DNF" || true)" ;;
    pacman) how="$(tools_guide_get "${tool}" "HOW_PACMAN" || true)" ;;
    apk) how="$(tools_guide_get "${tool}" "HOW_APK" || true)" ;;
    brew) how="$(tools_guide_get "${tool}" "HOW_BREW" || true)" ;;
    *) how="" ;;
  esac
  printf '%s\n' "${how}"
}
