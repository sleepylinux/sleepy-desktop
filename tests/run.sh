#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

if ! command -v qmltestrunner >/dev/null 2>&1; then
  printf 'FAIL: qmltestrunner is required for runnable QML behavior tests\n' >&2
  exit 1
fi

export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}"
export QT_QUICK_BACKEND="${QT_QUICK_BACKEND:-software}"
export QML2_IMPORT_PATH="$repo_root/src${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"

qmltestrunner -input "$repo_root/tests/qml" -import "$repo_root/src" -v1
