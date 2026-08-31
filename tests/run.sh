#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

bash "$repo_root/tests/upstream-provenance.sh"
bash "$repo_root/tests/dependencies.sh"
bash "$repo_root/tests/artwork-manifest.sh"
bash "$repo_root/tests/motion-contracts.sh"
bash "$repo_root/tests/ipc-contracts.sh"
bash "$repo_root/tests/m3-contracts.sh"
bash "$repo_root/tests/runtime-names.sh"
bash "$repo_root/tests/service-boundary.sh"
bash "$repo_root/tests/native-plugin-contracts.sh"

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
qml_timeout_seconds="${SLEEPY_QML_TIMEOUT_SECONDS:-120}"
if [[ ! "$qml_timeout_seconds" =~ ^[1-9][0-9]*$ ]]; then
  printf 'FAIL: SLEEPY_QML_TIMEOUT_SECONDS must be a positive integer\n' >&2
  exit 1
fi

timeout --signal=TERM --kill-after=5s "$qml_timeout_seconds" \
  "$qml_test_runner" -input "$repo_root/tests/qml" -import "$repo_root/src" -v1

# Qt Quick's painter-style software backend intentionally does not execute
# Re-run real production surfaces and the icon mask path with the RHI
# scenegraph and Mesa software rendering. Each runner remains independently
# bounded so a driver or scenegraph hang cannot be hidden.
for rhi_test in tst_icons.qml tst_m3_gallery.qml tst_m3_surfaces.qml; do
  QT_QUICK_BACKEND=rhi \
  QSG_RHI_BACKEND="${SLEEPY_TEST_RHI_BACKEND:-opengl}" \
  LIBGL_ALWAYS_SOFTWARE=1 \
  timeout --signal=TERM --kill-after=5s "$qml_timeout_seconds" \
    "$qml_test_runner" \
    -input "$repo_root/tests/qml/$rhi_test" \
    -import "$repo_root/src" \
    -v1
done
