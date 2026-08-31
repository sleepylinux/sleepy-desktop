#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
failed=0

if rg -n '^import "modules|^import "modules/(drawers|background|areapicker|lock)"|\b(Background|Drawers|AreaPicker|Lock|Shortcuts|BatteryMonitor|IdleMonitors)[[:space:]]*\{' \
    "$repo_root/src/shell.qml"; then
  printf 'FAIL: production shell must not instantiate or import quarantined visual modules in Task 6\n' >&2
  failed=1
fi

while IFS= read -r -d '' file; do
  relative="${file#"$repo_root"/}"
  if rg -n '\bProcess[[:space:]]*[{:]|Quickshell\.execDetached' "$file"; then
    printf 'FAIL: QML service code may not spawn local processes: %s\n' "$relative" >&2
    failed=1
  fi
  if rg -n '\b(nmcli|bluetoothctl|wpctl|playerctl|brightnessctl|powerprofilesctl|upower|hyprctl|loginctl|systemctl)\b' "$file"; then
    printf 'FAIL: QML service code may not call desktop command helpers directly: %s\n' "$relative" >&2
    failed=1
  fi
  if rg -n 'import Quickshell\.(Services|Hyprland)|\b(FileView|JsonAdapter|PersistentProperties|FileSystemModel)\b|Requests\.|CUtils\.(saveItem|copyFile|deleteFile)|\b(Hyprland|Pipewire|Mpris|Notifications)\.' "$file"; then
    printf 'FAIL: QML service code must use the sleepy-sessiond desktop model boundary: %s\n' "$relative" >&2
    failed=1
  fi
done < <(
  find "$repo_root/src/services" \
    -type f \
    -name '*.qml' \
    -print0
)

if rg -n 'import Sleepy\.(Services|Models)' "$repo_root/src/shell.qml" "$repo_root/src/services"; then
  printf 'FAIL: active runtime QML must not import unbuilt Sleepy.Services or Sleepy.Models modules\n' >&2
  failed=1
fi

if [[ $failed -ne 0 ]]; then
  exit 1
fi
