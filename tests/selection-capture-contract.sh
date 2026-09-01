#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
header="$repo_root/src/plugin/src/Sleepy/cutils.hpp"
impl="$repo_root/src/plugin/src/Sleepy/cutils.cpp"
picker="$repo_root/src/modules/areapicker/Picker.qml"

rg -F 'copyItemToClipboard(QQuickItem* target, const QRect& rect, QJSValue onCopied)' "$header" >/dev/null
rg -F 'saveItemToTemp(QQuickItem* target, const QRect& rect, QJSValue onSaved)' "$header" >/dev/null
rg -F 'QGuiApplication::clipboard()->setImage(image);' "$impl" >/dev/null
rg -F 'sleepy-picker-' "$impl" >/dev/null
rg -F 'CUtils.copyItemToClipboard(screencopy, selectionRect' "$picker" >/dev/null
rg -F 'CUtils.saveItemToTemp(screencopy, selectionRect' "$picker" >/dev/null

if rg -F 'CUtils.saveItem(' "$picker" >/dev/null; then
  printf 'FAIL: area picker may not choose an arbitrary native write path\n' >&2
  exit 1
fi
if rg -F 'CommandClient.utility' "$picker" >/dev/null; then
  printf 'FAIL: local selection capture may not masquerade as a session output command\n' >&2
  exit 1
fi

printf 'PASS: area selection uses constrained native clipboard and temporary-image helpers\n'
