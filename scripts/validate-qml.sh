#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$repo_root/scripts/lib/qml-tooling.sh"

if ! command -v jq >/dev/null 2>&1; then
  printf 'FAIL: jq is required to validate the QML import scanner output\n' >&2
  exit 1
fi

resolve_qt6_tool() {
  local tool_name="$1"
  local candidate

  for candidate in \
    "/usr/lib/qt6/bin/$tool_name" \
    "/usr/lib/qt6/$tool_name" \
    "$(command -v "${tool_name}-qt6" 2>/dev/null || true)" \
    "$(command -v "$tool_name" 2>/dev/null || true)"; do
    [[ -n "$candidate" && -x "$candidate" ]] || continue
    if ldd "$candidate" 2>/dev/null | grep -q 'libQt6' \
        || "$candidate" --version 2>&1 | grep -qE '(^| )6\.'; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  printf 'FAIL: Qt 6 %s is required; a Qt 5 binary is not sufficient\n' "$tool_name" >&2
  return 1
}

qmllint_bin="$(resolve_qt6_tool qmllint)"
qmlcachegen_bin="$(resolve_qt6_tool qmlcachegen)"
qmlimportscanner_bin="$(resolve_qt6_tool qmlimportscanner)"

if [[ -n ${SLEEPY_QUICKSHELL_BIN:-} ]]; then
  quickshell_bin="$SLEEPY_QUICKSHELL_BIN"
else
  quickshell_bin="$(command -v quickshell 2>/dev/null || true)"
fi

if [[ -z "$quickshell_bin" || ! -x "$quickshell_bin" ]]; then
  printf 'FAIL: Quickshell is required so its QML modules can be validated\n' >&2
  exit 1
fi

quickshell_import_root="$(find_quickshell_import_root \
  "$quickshell_bin" "$qmllint_bin" "$qmlcachegen_bin" "$qmlimportscanner_bin")"

mapfile -t qml_files < <(find "$repo_root/src" -type f -name '*.qml' -print | sort)
if [[ ${#qml_files[@]} -eq 0 ]]; then
  printf 'FAIL: no QML files found below %s/src\n' "$repo_root" >&2
  exit 1
fi

"$qmlimportscanner_bin" \
  -rootPath "$repo_root/src" \
  -importPath "$repo_root/src" \
  -importPath "$quickshell_import_root" \
  | jq -e 'type == "array" and length > 0' >/dev/null

"$qmllint_bin" \
  -I "$repo_root/src" \
  -I "$quickshell_import_root" \
  "${qml_files[@]}"

validation_tmp="$(mktemp -d)"
trap 'rm -rf "$validation_tmp"' EXIT

"$qmlcachegen_bin" --only-bytecode \
  -I "$repo_root/src" \
  -I "$quickshell_import_root" \
  -o "$validation_tmp/shell.qmlc" \
  "$repo_root/src/shell.qml"

"$qmlcachegen_bin" --only-bytecode \
  -I "$repo_root/src" \
  -I "$quickshell_import_root" \
  -o "$validation_tmp/settings-preview.qmlc" \
  "$repo_root/src/preview/main.qml"

printf 'PASS: Qt 6 import scan, qmllint, and bytecode compilation succeeded (%s)\n' \
  "$("$quickshell_bin" --version | head -n 1)"
