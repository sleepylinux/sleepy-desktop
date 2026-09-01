#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
qml_import_path="${SLEEPY_NATIVE_QML_IMPORT_PATH:-}"

if [[ -z "$qml_import_path" || ! -d "$qml_import_path/Sleepy" ]]; then
  printf 'FAIL: SLEEPY_NATIVE_QML_IMPORT_PATH must contain the installed Sleepy QML plugin\n' >&2
  exit 1
fi

if [[ -x /usr/lib/qt6/bin/qmltestrunner ]]; then
  qml_test_runner=/usr/lib/qt6/bin/qmltestrunner
elif command -v qmltestrunner-qt6 >/dev/null 2>&1; then
  qml_test_runner="$(command -v qmltestrunner-qt6)"
else
  printf 'FAIL: Qt 6 qmltestrunner is required for settings validation\n' >&2
  exit 1
fi

fixture_root="$(mktemp -d)"
cleanup() {
  rm -rf -- "$fixture_root"
}
trap cleanup EXIT

config_root="$fixture_root/config"
data_root="$fixture_root/data"
state_root="$fixture_root/state"
cache_root="$fixture_root/cache"
install -Dm600 "$repo_root/tests/fixtures/full-settings.json" "$config_root/sleepy/shell.json"
install -Dm600 "$repo_root/tests/fixtures/full-settings-monitor.json" \
  "$config_root/sleepy/monitors/DP-1/shell.json"

env \
  XDG_CONFIG_HOME="$config_root" \
  XDG_DATA_HOME="$data_root" \
  XDG_STATE_HOME="$state_root" \
  XDG_CACHE_HOME="$cache_root" \
  QT_QPA_PLATFORM=offscreen \
  QT_QUICK_BACKEND=software \
  "$qml_test_runner" \
    -input "$repo_root/tests/qml-native/tst_full_settings.qml" \
    -import "$qml_import_path" -v1

jq -e '
  .bar.dragThreshold == 33 and
  .futureCompatible.enabled == true and
  .futureCompatible.payload == "must-survive-save"
' "$config_root/sleepy/shell.json" >/dev/null

jq -e '
  .bar.dragThreshold == 49 and
  .futureMonitorCompatible.payload == "must-survive-monitor-save"
' "$config_root/sleepy/monitors/DP-1/shell.json" >/dev/null

rg -Fq 'u"/sleepy"_s' "$repo_root/src/plugin/src/Sleepy/Config/common.cpp"
for xdg_path in data state cache config; do
  rg -n "readonly property string $xdg_path:.*sleepy" "$repo_root/src/utils/Paths.qml" >/dev/null
done

printf 'PASS: full settings schema, layered overrides, XDG identity, and unknown-key preservation\n'
