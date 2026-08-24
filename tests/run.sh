#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

"$repo_root/tests/dependencies.sh"

if [[ -x /usr/lib/qt6/bin/qmltestrunner ]]; then
  qml_test_runner=/usr/lib/qt6/bin/qmltestrunner
elif command -v qmltestrunner-qt6 >/dev/null 2>&1; then
  qml_test_runner="$(command -v qmltestrunner-qt6)"
elif command -v qmltestrunner >/dev/null 2>&1 \
    && ldd "$(command -v qmltestrunner)" 2>/dev/null | grep -q 'libQt6'; then
  qml_test_runner="$(command -v qmltestrunner)"
else
  printf 'FAIL: qmltestrunner is required for runnable QML behavior tests\n' >&2
  exit 1
fi

export QT_QPA_PLATFORM="${SLEEPY_TEST_QPA_PLATFORM:-offscreen}"
export QT_QUICK_BACKEND="${SLEEPY_TEST_QUICK_BACKEND:-software}"
export QML_XHR_ALLOW_FILE_READ=1
export QML2_IMPORT_PATH="$repo_root/src${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"

"$qml_test_runner" -input "$repo_root/tests/qml" -import "$repo_root/src" -v1
