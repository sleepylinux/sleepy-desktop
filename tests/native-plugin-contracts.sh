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
rg -Fq '(pkgs.lib.cmakeBool "SLEEPY_AUDITED_RENDER_HELPERS_ONLY" true)' "$flake" \
  || fail 'native plugin build must request the audited render-helper profile'
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

if rg -n 'pkg_check_modules|Qt::DBus|Qt::Network|Qt::Sql|PkgConfig::(Qalculate|Pipewire|Aubio|Cava)|Sensors::Sensors' \
    "$plugin_cmake" "$core_cmake"; then
  fail 'active native plugin CMake must not compile daemon-owned system service dependencies'
fi

for required in Settings Config Components Blobs Images; do
  if ! rg -n "add_subdirectory\\($required\\)" "$core_cmake" >/dev/null; then
    fail "active native plugin must keep audited Sleepy.$required visual/config helpers"
  fi
done

for forbidden in Models Services; do
  if rg -n "add_subdirectory\\($forbidden\\)" "$core_cmake"; then
    fail "active native plugin must not build daemon-owned Sleepy.$forbidden helpers"
  fi
done

if rg -n 'qalculator\.cpp|requests\.cpp' "$core_cmake"; then
  fail 'native Sleepy core must not expose calculator or raw network request helpers'
fi

if rg -n 'Q_INVOKABLE.*(saveItem|copyFile|deleteFile)|CUtils::(saveItem|copyFile|deleteFile)' \
    "$cutils_header" "$cutils_source"; then
  fail 'native CUtils must not expose direct file mutation helpers'
fi

printf 'PASS: native plugin packaging is pinned and limited to audited render helpers\n'
