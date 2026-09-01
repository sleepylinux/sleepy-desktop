#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$repo_root/tests/lib/qt6-moc-resolver.sh"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/sleepy-desktop-socket.XXXXXX")"
stub_root="$test_root/qml-stubs"
io_module="$stub_root/Quickshell/Io"
cleanup() {
    rm -rf -- "$test_root"
}
trap cleanup EXIT

if [[ -x /usr/lib/qt6/bin/qmltestrunner ]]; then
    qml_test_runner=/usr/lib/qt6/bin/qmltestrunner
elif command -v qmltestrunner-qt6 >/dev/null 2>&1; then
    qml_test_runner="$(command -v qmltestrunner-qt6)"
elif command -v qmltestrunner >/dev/null 2>&1 \
        && ldd "$(command -v qmltestrunner)" 2>/dev/null | grep -q 'libQt6'; then
    qml_test_runner="$(command -v qmltestrunner)"
else
    printf 'FAIL: Qt 6 qmltestrunner is required for Socket lifecycle validation\n' >&2
    exit 1
fi

moc_binary="$(resolve_qt6_moc || true)"
if [[ -z "$moc_binary" ]] || ! command -v c++ >/dev/null 2>&1 \
        || ! pkg-config --exists Qt6Core Qt6Qml; then
    printf 'FAIL: Qt 6 moc, C++ compiler, and Qt6Qml pkg-config metadata are required\n' >&2
    exit 1
fi

mkdir -p "$stub_root"
cp -a "$repo_root/tests/qml-stubs/Quickshell" "$stub_root/"
rm -f -- "$io_module/Socket.qml"
cp "$repo_root/tests/socket-contract-plugin.cpp" "$test_root/socket-contract-plugin.cpp"
"$moc_binary" "$test_root/socket-contract-plugin.cpp" \
    -o "$test_root/socket-contract-plugin.moc"
c++ -std=c++20 -fPIC -shared "$test_root/socket-contract-plugin.cpp" \
    -I"$test_root" $(pkg-config --cflags --libs Qt6Core Qt6Qml) \
    -o "$io_module/libsleepysocketcontractplugin.so"
cp "$repo_root/tests/socket-contract-qmldir" "$io_module/qmldir"

unset WAYLAND_DISPLAY WAYLAND_SOCKET HYPRLAND_INSTANCE_SIGNATURE SWAYSOCK I3SOCK
unset QT_QPA_PLATFORMTHEME KDE_FULL_SESSION XDG_CURRENT_DESKTOP
export KDE_DEBUG=1
export QT_STYLE_OVERRIDE=Fusion
export QT_QPA_PLATFORM=offscreen
export QT_QUICK_BACKEND=software
export QML_XHR_ALLOW_FILE_READ=1
export QML2_IMPORT_PATH="$stub_root:$repo_root/src"

timeout --signal=TERM --kill-after=5s 30s \
    "$qml_test_runner" \
      -input "$repo_root/tests/qml-socket-contract/tst_desktop_client_socket_contract.qml" \
      -import "$stub_root" \
      -import "$repo_root/src" \
      -v1
