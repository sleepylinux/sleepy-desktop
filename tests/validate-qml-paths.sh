#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$repo_root/scripts/lib/qml-tooling.sh"

test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

derived_prefix="$test_root/derived"
mkdir -p "$derived_prefix/bin" "$derived_prefix/lib/qt6/qml/Quickshell"
touch "$derived_prefix/bin/quickshell" "$derived_prefix/lib/qt6/qml/Quickshell/qmldir"
chmod +x "$derived_prefix/bin/quickshell"

unset SLEEPY_QUICKSHELL_IMPORT_PATH QML_IMPORT_PATH QML2_IMPORT_PATH
actual="$(find_quickshell_import_root "$derived_prefix/bin/quickshell")"
if [[ "$actual" != "$derived_prefix/lib/qt6/qml" ]]; then
  printf 'FAIL: derived prefix mismatch: %s\n' "$actual" >&2
  exit 1
fi

override_root="$test_root/override/qml"
mkdir -p "$override_root/Quickshell"
touch "$override_root/Quickshell/qmldir"
SLEEPY_QUICKSHELL_IMPORT_PATH="$override_root"
actual="$(find_quickshell_import_root "$derived_prefix/bin/quickshell")"
if [[ "$actual" != "$override_root" ]]; then
  printf 'FAIL: explicit override did not take precedence: %s\n' "$actual" >&2
  exit 1
fi

SLEEPY_QUICKSHELL_IMPORT_PATH="$test_root/missing"
if find_quickshell_import_root "$derived_prefix/bin/quickshell" >/dev/null 2>&1; then
  printf 'FAIL: invalid explicit override must fail instead of falling back\n' >&2
  exit 1
fi

printf 'PASS: Quickshell import discovery supports derived and explicit prefixes\n'
