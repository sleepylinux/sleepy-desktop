#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
shell="$repo_root/src/shell.qml"
failed=0

if [[ $# -gt 1 ]]; then
  printf 'usage: %s [searcher-source-root]\n' "$0" >&2
  exit 2
fi

python3 "$repo_root/tests/active-graph.py" "$shell" || failed=1

for module_root in modules modules/drawers modules/background modules/areapicker; do
  if ! rg -Fq "import \"$module_root\"" "$shell"; then
    printf 'FAIL: packaged shell is missing reviewed module root: %s\n' "$module_root" >&2
    failed=1
  fi
done

if ! rg -Fq -- '--set QML2_IMPORT_PATH "${qtQmlImportPath}"' "$repo_root/flake.nix" ||
    ! rg -Fq -- '--set QML_IMPORT_PATH "${qtQmlImportPath}"' "$repo_root/flake.nix"; then
  printf 'FAIL: flake wrapper must close QML imports to the reviewed runtime path\n' >&2
  failed=1
fi

if ! rg -Fq 'rm -rf "$out/${installRoot}/modules/lock" "$out/${installRoot}/assets/pam.d"' "$repo_root/flake.nix" ||
    ! rg -Fq 'modules/lock' "$repo_root/src/CMakeLists.txt" ||
    ! rg -Fq 'assets/pam.d' "$repo_root/src/CMakeLists.txt"; then
  printf 'FAIL: production installs must remove quarantined lock/PAM files\n' >&2
  failed=1
fi

searcher_source_root="${1:-$repo_root/src}"
while IFS= read -r searcher_consumer; do
  if ! awk '
    /^[[:space:]]*import[[:space:]]+qs[.]utils([[:space:]]+[0-9]+[.][0-9]+)?[[:space:]]*(\/\/.*)?$/ {
      found = 1
    }
    END { exit found ? 0 : 1 }
  ' "$searcher_consumer"; then
    printf 'FAIL: Searcher consumer must import its owning qs.utils module: %s\n' \
      "${searcher_consumer#"$searcher_source_root"/}" >&2
    failed=1
  fi
done < <(rg -l '^[[:space:]]*Searcher[[:space:]]*\{' "$searcher_source_root" -g '*.qml')

if [[ $failed -ne 0 ]]; then
  exit 1
fi

printf 'PASS: packaged shell uses the closed reviewed modular import path\n'
