#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
manifest="$repo_root/tests/parity-manifest.json"
upstream_inventory="$repo_root/tests/fixtures/upstream-v2.4.0-parity-inventory.json"
evidence_registry="$repo_root/tests/parity-evidence-registry.json"
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
production-compositor-hotplug-private-wayland
production-mixed-scale-two-monitor-private-wayland
window-details-pinned-group-move-preview-deviation
CASES

validate_parity_manifest "$manifest" "$upstream_inventory" \
  "$scratch/inventory" "$scratch/required-cases" "$repo_root" \
  "$evidence_registry" \
  '867574e4fdb909b1349dd519a5a2fc47f4958845f9d01558c91df050dd6ef5ba' \
  367 363 4 \
  '["src/services/PresetAdapter.qml","src/services/SessionAdapter.qml","src/services/SessionEventClient.qml","src/services/SystemAdapter.qml"]' \
  'git diff --name-status d5e10fb^ d5e10fb, normalized QML/C++ paths under imported modules, services, and plugin'

printf 'PASS: immutable upstream parity inventory and Task 10 objective matrix\n'
