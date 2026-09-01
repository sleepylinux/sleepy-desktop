#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT

run_contract() {
  bash "$repo_root/tests/closed-imports.sh" "$1"
}

aliased_root="$test_root/aliased"
mkdir -p "$aliased_root"
cat >"$aliased_root/Aliased.qml" <<'QML'
import QtQuick
import qs.utils as Utils

Searcher {
}
QML

if run_contract "$aliased_root" >"$test_root/aliased.out" 2>"$test_root/aliased.err"; then
  printf 'FAIL: aliased qs.utils import was accepted for an unqualified Searcher consumer\n' >&2
  exit 1
fi
if ! rg -Fq 'Searcher consumer must import its owning qs.utils module' "$test_root/aliased.err"; then
  printf 'FAIL: aliased import rejection did not report the Searcher owner contract\n' >&2
  exit 1
fi

unaliased_root="$test_root/unaliased"
mkdir -p "$unaliased_root"
cat >"$unaliased_root/Plain.qml" <<'QML'
import QtQuick
import qs.utils

Searcher {
}
QML
cat >"$unaliased_root/Versioned.qml" <<'QML'
import QtQuick
  import   qs.utils   1.0   // direct owner import

Searcher {
}
QML

if ! run_contract "$unaliased_root" >"$test_root/unaliased.out" 2>"$test_root/unaliased.err"; then
  printf 'FAIL: valid unaliased qs.utils import forms were rejected\n' >&2
  cat "$test_root/unaliased.err" >&2
  exit 1
fi

printf 'PASS: Searcher owner import rejects aliases and accepts unaliased QML forms\n'
