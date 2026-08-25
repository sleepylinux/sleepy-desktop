#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

for file in \
  src/services/SessionEventClient.qml \
  src/services/DailyClient.qml \
  src/services/OsdClient.qml \
  src/services/ThemeClient.qml \
  src/services/ClientRequestLifecycle.qml \
  src/services/ControlClient.qml \
  src/services/NotificationClient.qml \
  src/drawers/DailyDesktopDrawer.qml \
  src/panels/OsdLayer.qml; do
  test -f "$repo_root/$file"
done

rg -Fq '[root.executable, "events", "watch", "--format", "ndjson"]' \
  "$repo_root/src/services/SessionEventClient.qml"
rg -Fq 'Socket {' "$repo_root/src/services/DailyClient.qml"
rg -Fq '/sleepy/daily.sock' "$repo_root/src/services/DailyClient.qml"
rg -Fq '/sleepy/osd.sock' "$repo_root/src/services/OsdClient.qml"
rg -Fq '/sleepy/theme.sock' "$repo_root/src/services/ThemeClient.qml"
rg -Fq '/sleepy/control.sock' "$repo_root/src/services/ControlClient.qml"
rg -Fq '/sleepy/notification.sock' "$repo_root/src/services/NotificationClient.qml"
for client in ControlClient NotificationClient; do
  rg -Fq 'ClientRequestLifecycle {' "$repo_root/src/services/$client.qml"
  rg -Fq 'root.lifecycle.finish()' "$repo_root/src/services/$client.qml"
done
rg -Fq 'if (root.pending) root.dirty = true' \
  "$repo_root/src/services/ClientRequestLifecycle.qml"
rg -Fq 'id: actionLabel; anchors.centerIn: parent; textFormat: Text.PlainText' \
  "$repo_root/src/drawers/DailySurfaceView.qml"
rg -Fq 'themeSocket.write(JSON.stringify(ack) + "\n")' \
  "$repo_root/src/services/ThemeClient.qml"
rg -Fq 'SLEEPY_QML_TIMEOUT_SECONDS' "$repo_root/tests/run.sh"
rg -Fq 'timeout --signal=TERM --kill-after=5s' "$repo_root/tests/run.sh"
rg -Fq "while [[ -e /tmp/.X''\${display_number}-lock" "$repo_root/flake.nix"
rg -Fq 'eventProcess.signal(9)' "$repo_root/src/services/SessionEventClient.qml"
for process in snapshot session; do
  rg -Fq "root.${process}Process.signal(9)" "$repo_root/src/services/SystemAdapter.qml"
done
if rg -n 'mutationProcess|sleepyctl.*system.*set' "$repo_root/src/services/SystemAdapter.qml"; then
  printf 'FAIL: production UI retained local M2 mutation authority\n' >&2
  exit 1
fi
rg -Fq 'root.settingsProcess.signal(9)' "$repo_root/src/services/SessionAdapter.qml"
rg -Fq 'root.activationProcess.signal(9)' "$repo_root/src/services/SessionAdapter.qml"
rg -Fq 'root.process.signal(9)' "$repo_root/src/services/PresetAdapter.qml"
rg -Fq 'portalDark: Application.styleHints.colorScheme !== Qt.Light' \
  "$repo_root/src/shell.qml"
if rg -n 'appearanceMode.*system.*dark' "$repo_root/src/shell.qml"; then
  printf 'FAIL: system appearance is hard-coded instead of portal-backed\n' >&2
  exit 1
fi

for surface in notifications launcher overview widgets personalization; do
  rg -Fq "[\"$surface\"" "$repo_root/src/services/SurfaceRegistry.qml"
done

for icon in notification notification-critical dnd dismiss archive launcher overview \
  window-close workspace calendar weather cpu memory disk audio-output media theme \
  palette wallpaper effects-full effects-reduced effects-none search refresh location \
  error offline unread; do
  rg -Fq "\"icons.$icon\"" "$repo_root/src/services/IconRegistry.qml"
done

if rg -n 'execDetached|\["niri"|\["nmcli"|\["wpctl"|\["brightnessctl"' \
    "$repo_root/src/services/WorkspaceService.qml" \
    "$repo_root/src/services/WorkspaceEventService.qml" \
    "$repo_root/src/services/ShellIpc.qml"; then
  printf 'FAIL: M3 runtime service contains a direct QML system probe/action\n' >&2
  exit 1
fi

if rg -n 'sh -c|bash -c|arbitraryCommand' "$repo_root/src"; then
  printf 'FAIL: shell interpolation or arbitrary launcher execution surface found\n' >&2
  exit 1
fi

test "$(jq -r '.outputs | length' "$repo_root/tests/fixtures/m3-gallery.json")" = 2
test "$(jq -r '.effects | length' "$repo_root/tests/fixtures/m3-gallery.json")" = 3

printf 'PASS: M3 event, socket, surface, icon and gallery contracts are present\n'
