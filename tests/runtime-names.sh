#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

allowed_source_notice='^[[:space:]]*(//|#|/\*|\*)[[:space:]]*(SPDX|Modified|Upstream|Derived|Forked|Based on)'
failed=0

check_file() {
  local file="$1"
  local relative="${file#"$repo_root"/}"

  case "$relative" in
    NOTICE|UPSTREAM.json|src/LICENSE|scripts/import-upstream.sh|tests/runtime-names.sh|tests/upstream-provenance.sh|tests/patch-inventory.json|tests/fixtures/upstream-v2.4.0-parity-inventory.json|tests/lib/parity-validator.sh|tests/parity-validator-test.sh|tests/active-graph.py|tests/fixtures/active-graph-forbidden/*)
      return 0
      ;;
  esac

  while IFS= read -r line; do
    if [[ $line =~ [Cc]aelestia ]]; then
      if [[ ! $line =~ $allowed_source_notice ]]; then
        printf 'FAIL: runtime Caelestia identity in %s: %s\n' "$relative" "$line" >&2
        failed=1
      fi
    fi
    if [[ $line =~ (org\.caelestia|caelestia-shell|caelestia[./_-]|CAELESTIA_|Caelestia\.) ]]; then
      printf 'FAIL: forbidden Caelestia runtime token in %s: %s\n' "$relative" "$line" >&2
      failed=1
    fi
  done <"$file"
}

while IFS= read -r -d '' file; do
  check_file "$file"
done < <(
  find "$repo_root/src" "$repo_root/scripts" "$repo_root/tests" \
    -type f \
    ! -path '*/.git/*' \
    -print0
)

for file in "$repo_root/flake.nix" "$repo_root/CMakeLists.txt"; do
  [[ -f "$file" ]] && check_file "$file"
done

about_page="$repo_root/src/modules/nexus/pages/AboutPage.qml"
if [[ ! -f "$about_page" ]] ||
    ! rg -Fq 'Open source notices' "$about_page" ||
    ! rg -Fq 'NOTICE' "$about_page"; then
  printf 'FAIL: About page must keep GPL notices and upstream credits discoverable\n' >&2
  failed=1
fi

for sleepy_path in \
  'u"/sleepy"_s' \
  '`${Quickshell.env("XDG_DATA_HOME") || `${home}/.local/share`}/sleepy`' \
  '`${Quickshell.env("XDG_STATE_HOME") || `${home}/.local/state`}/sleepy`' \
  '`${Quickshell.env("XDG_CACHE_HOME") || `${home}/.cache`}/sleepy`' \
  '`${Quickshell.env("XDG_CONFIG_HOME") || `${home}/.config`}/sleepy`'; do
  if ! rg -Fq "$sleepy_path" \
      "$repo_root/src/plugin/src/Sleepy/Config/common.cpp" \
      "$repo_root/src/utils/Paths.qml"; then
    printf 'FAIL: missing Sleepy-owned runtime path: %s\n' "$sleepy_path" >&2
    failed=1
  fi
done

if ! rg -Fq 'QStringList, terminal, { u"ghostty"_s }' \
    "$repo_root/src/plugin/src/Sleepy/Config/generalconfig.hpp"; then
  printf 'FAIL: Sleepy shell must default to the session-owned Ghostty terminal\n' >&2
  failed=1
fi

if [[ -n "${SLEEPY_ARTWORK_ROOT:-}" ]] \
    && ! cmp -s "$repo_root/src/assets/logo.svg" "$SLEEPY_ARTWORK_ROOT/branding/logo.svg"; then
  printf 'FAIL: packaged shell logo must match the pinned sleepy-artwork primary mark\n' >&2
  failed=1
fi

if [[ $failed -ne 0 ]]; then
  exit 1
fi
