#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
shell="$repo_root/src/shell.qml"
failed=0

if rg -n '^import "modules' "$shell"; then
  printf 'FAIL: packaged shell must not depend on quarantined module import roots\n' >&2
  failed=1
fi

if rg -n '^import Sleepy\.(Services|Models)' "$shell" "$repo_root/src/services"; then
  printf 'FAIL: packaged active graph must not import unbuilt native Sleepy.Services or Sleepy.Models\n' >&2
  failed=1
fi

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

while IFS= read -r searcher_consumer; do
  if ! rg -q '^import qs\.utils([[:space:]]|$)' "$searcher_consumer"; then
    printf 'FAIL: Searcher consumer must import its owning qs.utils module: %s\n' \
      "${searcher_consumer#"$repo_root"/}" >&2
    failed=1
  fi
done < <(rg -l '^[[:space:]]*Searcher[[:space:]]*\{' "$repo_root/src" -g '*.qml')

if [[ $failed -ne 0 ]]; then
  exit 1
fi

printf 'PASS: packaged shell uses the closed Task 6 import path\n'
