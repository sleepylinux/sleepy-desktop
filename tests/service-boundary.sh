#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
shell="$repo_root/src/shell.qml"
idle="$repo_root/src/modules/IdleMonitors.qml"
session_surface="$repo_root/src/modules/session/Content.qml"
launcher_actions="$repo_root/src/modules/launcher/services/Actions.qml"
battery_monitor="$repo_root/src/modules/BatteryMonitor.qml"
failed=0

python3 "$repo_root/tests/active-graph.py" "$shell"

for integration in \
  'import Quickshell.Hyprland' \
  'import Quickshell.Services.Pipewire' \
  'import Quickshell.Services.Mpris' \
  'import Quickshell.Services.Notifications' \
  'import Quickshell.Services.UPower' \
  'import Quickshell.Services.SystemTray' \
  'import Sleepy.Services' \
  'import Sleepy.Models'; do
  if ! rg -Fq "$integration" "$repo_root/src"; then
    printf 'FAIL: reviewed direct integration disappeared: %s\n' "$integration" >&2
    failed=1
  fi
done

for provider in Hypr.qml Nmcli.qml Audio.qml Brightness.qml Players.qml Notifs.qml Colours.qml Wallpapers.qml Weather.qml VPN.qml; do
  if rg -n 'DesktopModel|CommandClient\.|DesktopCommands\.' "$repo_root/src/services/$provider"; then
    printf 'FAIL: direct provider %s must not proxy through sleepy-sessiond\n' "$provider" >&2
    failed=1
  fi
done

if ! jq -e '
  [.providers[].id] | sort ==
    ["appearance", "applications", "audio", "brightness", "clipboard", "hyprland", "media",
     "network", "notifications", "power", "screenshot", "tray", "vpn", "weather"]
' "$repo_root/tests/direct-integrations.json" >/dev/null; then
  printf 'FAIL: reviewed direct provider registry is incomplete\n' >&2
  failed=1
fi

if ! rg -Fq 'CommandClient.session(DesktopCommands.session("lock"))' "$idle"; then
  printf 'FAIL: idle and login1 lock requests must route through sleepy-sessiond\n' >&2
  failed=1
fi
if rg -n 'SessionManager\.(exec|logout|suspend|suspendThenHibernate|hibernate|poweroff|reboot)' \
    "$repo_root/src"; then
  printf 'FAIL: production session mutations must route through desktop-control.sock\n' >&2
  failed=1
fi
for path in "$session_surface" "$launcher_actions" "$battery_monitor" "$idle"; do
  if ! rg -Fq 'SessionActions.' "$path"; then
    printf 'FAIL: %s must use the typed Sleepy session action router\n' "$path" >&2
    failed=1
  fi
done
if rg -n 'Quickshell\.execDetached\(action\)' "$idle" \
    || ! rg -Fq '!SessionActions.exec(command) && !dangerous' "$launcher_actions"; then
  printf 'FAIL: configurable session/idle actions may not fall back to arbitrary privileged argv\n' >&2
  failed=1
fi
if rg -n '^import "lock"|\bLock\s*\{|lock\.lock\.' "$shell" "$idle"; then
  printf 'FAIL: the general shell must never own the secure session lock\n' >&2
  failed=1
fi

if [[ $failed -ne 0 ]]; then
  exit 1
fi

printf 'PASS: Sleepy service boundary permits reviewed native integrations and delegates secure lock\n'
