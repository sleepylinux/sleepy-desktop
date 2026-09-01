#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
manifest="$repo_root/tests/parity-manifest.json"
source "$repo_root/tests/lib/parity-validator.sh"

scratch="$(mktemp -d)"
trap 'rm -rf -- "$scratch"' EXIT
(
  cd "$repo_root"
  rg --files src/modules src/services src/plugin \
    | awk '/\.qml$|\.(cpp|hpp|h)$/' \
    | LC_ALL=C sort
) >"$scratch/inventory"

cat >"$scratch/required-cases" <<'CASES'
bar-active-occupied-special-per-monitor
tray-dbusmenu-action
launcher-apps-calculation-scheme-wallpaper-keyboard-failure
dashboard-sidebar-online-offline
osd-volume-mute-microphone-brightness-power-unavailable
lock-session-auth-crash-suspend-power-denial
network-bluetooth-audio-independent-degradation
media-lyrics-multiple-missing-transport-failure
utilities-idle-record-screenshot-selection-color-game
compositor-window-actions-special-hotplug
appearance-wallpaper-theme-motion-opaque-scale-two-monitors
CASES

validate_parity_manifest "$manifest" "$scratch/inventory" \
  "$scratch/required-cases" "$repo_root"

printf 'PASS: exhaustive upstream parity inventory and Task 10 objective matrix\n'
