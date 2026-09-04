#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
scenarios="$root/tests/reference/scenarios.json"
mask="$root/tests/reference/masks/sleepy-branding.json"

jq -e '
  .formatVersion == 1 and
  ([.scenarios[].id] | length == (unique | length)) and
  ([.scenarios[] | select(.kind != "still" and .kind != "animation")] | length == 0) and
  ([.scenarios[] | select(.kind == "animation" and ((.frameTimestampsMs | length) < 2))] | length == 0)
' "$scenarios" >/dev/null

for required in \
  desktop-one-monitor desktop-two-monitors desktop-mixed-scale monitor-hotplug \
  bar-popouts launcher-applications launcher-calculator launcher-schemes launcher-wallpapers \
  dashboard-dash dashboard-media dashboard-weather dashboard-performance \
  sidebar-notifications notification-overlay nexus-network nexus-audio nexus-appearance nexus-dialogs \
  osd-audio-brightness-lock session-menu utilities window-info secure-lock \
  reduced-motion effects-disabled fullscreen-suppression; do
  [[ "$(jq -r --arg id "$required" '[.scenarios[] | select(.id == $id)] | length' "$scenarios")" == 1 ]] \
    || { printf 'FAIL: missing deterministic scenario %s\n' "$required" >&2; exit 1; }
done

jq -e '.formatVersion == 1 and (.regions | length) == 3 and (.surfaces | type) == "array"' "$mask" >/dev/null
if rg -n '(eval|sh -c|bash -c)' "$root/tests/reference/capture.sh"; then
  printf 'FAIL: reference capture driver must not interpret commands\n' >&2
  exit 1
fi
printf 'PASS: deterministic reference scenarios cover every required shell state\n'
