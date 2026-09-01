#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
flake="$repo_root/flake.nix"
plugin_cmake="$repo_root/src/plugin/CMakeLists.txt"
core_cmake="$repo_root/src/plugin/src/Sleepy/CMakeLists.txt"
cutils_header="$repo_root/src/plugin/src/Sleepy/cutils.hpp"
cutils_source="$repo_root/src/plugin/src/Sleepy/cutils.cpp"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

rg -Fq 'quickshell = {' "$flake" \
  || fail 'flake must declare the reviewed Quickshell input'
rg -Fq 'git+https://git.outfoxxed.me/outfoxxed/quickshell?rev=0fed22a2c47d9568ddf13cf61586b3f2ac4378a2' "$flake" \
  || fail 'flake must pin Quickshell to the reviewed upstream revision'
rg -Fq 'm3shapes = {' "$flake" \
  || fail 'flake must declare the reviewed m3shapes input'
rg -Fq 'github:soramanew/m3shapes/32ad9ce328bb77ed349b40a3be10ee9ea610b8ab' "$flake" \
  || fail 'flake must pin m3shapes to the reviewed upstream revision'
rg -Fq 'quickshellPackage = quickshell.packages.${system}.default.override {' "$flake" \
  || fail 'desktop packages must use the pinned Quickshell package input'
rg -Fq 'quickshellWithModules = quickshellPackage.withModules [ pkgs.qt6.qtimageformats m3shapesPackage ];' "$flake" \
  || fail 'desktop packages must include pinned m3shapes through Quickshell modules'
rg -Fq 'nativePlugin = pkgs.clangStdenv.mkDerivation {' "$flake" \
  || fail 'flake must build the renamed native QML plugin'
rg -Fq 'pname = "sleepy-qml-plugin";' "$flake" \
  || fail 'native plugin package must be Sleepy-named'
if rg -Fq '(pkgs.lib.cmakeBool "SLEEPY_AUDITED_RENDER_HELPERS_ONLY" true)' "$flake"; then
  fail 'native plugin build must not request the obsolete render-helper-only profile'
fi
rg -Fq 'qtQmlImportPath =' "$flake" \
  || fail 'flake must centralize the closed QML import path'
rg -Fq '${nativePlugin}/${pkgs.qt6.qtbase.qtQmlPrefix}' "$flake" \
  || fail 'packaged QML import path must include the built Sleepy native plugin'
rg -Fq 'runner = "${quickshellWithModules}/bin/qs";' "$flake" \
  || fail 'sleepy-shell must run the pinned Quickshell-with-m3shapes package'
rg -Fq 'nativePlugin' "$flake" \
  || fail 'package checks must reference the native plugin package'

if rg -n '[c]aelestia-cli|with-cli|pkgs\.quickshell|[c]aelestia-shell' "$flake"; then
  fail 'desktop flake must not depend on the upstream CLI or ambient nixpkgs Quickshell'
fi

for dependency in aubio fftw pipewire libcava lm_sensors libqalculate; do
  rg -Fq "pkgs.$dependency" "$flake" \
    || fail "native plugin build is missing dependency: $dependency"
done
for dependency in qtimageformats qtshadertools; do
  rg -Fq "pkgs.qt6.$dependency" "$flake" \
    || fail "native plugin build is missing Qt dependency: $dependency"
done

for required in Settings Config Components Blobs Images Models Services; do
  if ! rg -n "add_subdirectory\\($required\\)" "$core_cmake" >/dev/null; then
    fail "active native plugin must build Sleepy.$required"
  fi
done

for source in qalculator.cpp requests.cpp; do
  rg -Fq "$source" "$core_cmake" \
    || fail "native Sleepy core must expose imported helper: $source"
done

for linkage in Qt::DBus Qt::Network Qt::Sql PkgConfig::Qalculate PkgConfig::Pipewire PkgConfig::Aubio PkgConfig::Cava Sensors::Sensors; do
  rg -Fq "$linkage" "$plugin_cmake" "$core_cmake" \
    "$repo_root/src/plugin/src/Sleepy/Services/CMakeLists.txt" \
    "$repo_root/src/plugin/src/Sleepy/Models/CMakeLists.txt" \
    || fail "native plugin is missing required linkage: $linkage"
done

test -f "$repo_root/tests/qml-native/tst_native_full_plugin.qml" \
  || fail 'full native plugin QML load test is missing'
test -f "$repo_root/tests/qml-native/tst_full_settings.qml" \
  || fail 'full native settings behavior test is missing'
test -x "$repo_root/tests/full-settings-contract.sh" \
  || fail 'full native settings contract runner is missing or not executable'

if rg -n 'Q_INVOKABLE.*(saveItem|copyFile|deleteFile)|CUtils::(saveItem|copyFile|deleteFile)' \
    "$cutils_header" "$cutils_source"; then
  fail 'native CUtils must not expose direct file mutation helpers'
fi

printf 'PASS: complete renamed native plugin graph and dependencies are declared\n'
