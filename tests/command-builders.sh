#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
failed=0

if [[ ! -f "$repo_root/src/services/DesktopCommands.js" ]]; then
  printf 'FAIL: active command builders must be centralized in src/services/DesktopCommands.js\n' >&2
  failed=1
fi

if rg -n '"type":[[:space:]]*"(setOutputVolume|setInputVolume|setDefaultOutput|setDefaultInput|previewWallpaper|stopWallpaperPreview|refreshWeather|dismiss|invoke|reloadDynamicConfig|refreshDevices|cycleSpecialWorkspace|message|play|pause|toggle|stop)"' \
    "$repo_root/src/services" --glob '*.qml'; then
  printf 'FAIL: active service code emits command variants outside the reviewed SDK v3 schema\n' >&2
  failed=1
fi

while IFS= read -r -d '' file; do
  relative="${file#"$repo_root"/}"
  if rg -q 'CommandClient\.(system|compositor|notification|launcher|appearance|utility|session)[[:space:]]*\(' "$file" &&
      ! rg -q 'import "DesktopCommands\.js" as DesktopCommands' "$file"; then
    printf 'FAIL: %s sends desktop commands without the centralized SDK v3 builder\n' "$relative" >&2
    failed=1
  fi
done < <(
  find "$repo_root/src/services" \
    -type f \
    -name '*.qml' \
    ! -name 'CommandClient.qml' \
    ! -name 'DesktopModel.qml' \
    -print0
)

if [[ $failed -ne 0 ]]; then
  exit 1
fi

printf 'PASS: active service command builders are centralized and SDK v3-shaped\n'
