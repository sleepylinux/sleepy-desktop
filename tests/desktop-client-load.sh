#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

if [[ -x /usr/lib/qt6/bin/qmltestrunner ]]; then
  qml_test_runner=/usr/lib/qt6/bin/qmltestrunner
elif command -v qmltestrunner-qt6 >/dev/null 2>&1; then
  qml_test_runner="$(command -v qmltestrunner-qt6)"
elif command -v qmltestrunner >/dev/null 2>&1 \
    && ldd "$(command -v qmltestrunner)" 2>/dev/null | grep -q 'libQt6'; then
  qml_test_runner="$(command -v qmltestrunner)"
else
  printf 'FAIL: Qt 6 qmltestrunner is required for DesktopClient load validation\n' >&2
  exit 1
fi

unset WAYLAND_DISPLAY WAYLAND_SOCKET HYPRLAND_INSTANCE_SIGNATURE SWAYSOCK I3SOCK
unset QT_QPA_PLATFORMTHEME KDE_FULL_SESSION XDG_CURRENT_DESKTOP
export KDE_DEBUG=1
export QT_STYLE_OVERRIDE=Fusion
export QT_QPA_PLATFORM=offscreen
export QT_QUICK_BACKEND=software
export QML_XHR_ALLOW_FILE_READ=1
export QML2_IMPORT_PATH="$repo_root/tests/qml-stubs:$repo_root/src"

timeout --signal=TERM --kill-after=5s 30s \
  "$qml_test_runner" \
    -input "$repo_root/tests/qml-load/tst_desktop_client_load.qml" \
    -import "$repo_root/tests/qml-stubs" \
    -import "$repo_root/src" \
    -v1
