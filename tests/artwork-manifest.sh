#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
artwork_root="${SLEEPY_ARTWORK_ROOT:-$repository_root/../sleepy-artwork}"
manifest="$artwork_root/branding/manifest.json"

test -f "$manifest"
test "$(jq -er '.version' "$manifest")" = 1

expected_icons=(
  control-center network bluetooth volume microphone brightness night-light
  focus battery power-profile media-play media-pause media-next media-previous
  lock logout power preset keybinding notification notification-critical dnd
  dismiss archive launcher overview window-close workspace calendar weather cpu
  memory disk audio-output media theme palette wallpaper effects-full
  effects-reduced effects-none search refresh location error offline unread
)

jq -e '.assets["branding.primaryMark"] == "branding/logo.svg"' \
  "$manifest" >/dev/null
test -f "$artwork_root/branding/logo.svg"

for icon_name in "${expected_icons[@]}"; do
  logical_name="icons.$icon_name"
  relative_path="icons/$icon_name.svg"
  jq -e --arg name "$logical_name" --arg path "$relative_path" \
    '.assets[$name] == $path' "$manifest" >/dev/null
  test -f "$artwork_root/$relative_path"
done

test "$(jq -er '.assets | length' "$manifest")" = 48
printf 'PASS: exact reviewed logical manifest values resolve to installed files\n'
