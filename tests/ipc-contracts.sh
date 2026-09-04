#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
shell="$repo_root/src/shell.qml"
ipc="$repo_root/src/services/ShellIpc.qml"
system_adapter="$repo_root/src/services/SystemAdapter.qml"

grep -Fxq '//@ pragma ShellId sleepy' "$shell"
grep -Fq 'target: "sleepy"' "$ipc"
for signature in \
  'function toggleControlCenter(): void' \
  'function openControlCenter(): void' \
  'function closeActiveSurface(): void' \
  'function openPowerMenu(): void' \
  'function requestSessionAction(action: string): void'; do
  grep -Fq "$signature" "$ipc"
done

grep -Fq 'property bool refreshAfterCurrent: false' "$system_adapter"
grep -Fq 'if (root.refreshAfterCurrent)' "$system_adapter"
grep -Fq 'function sessionAction(action: string): bool' "$ipc"
grep -Fq 'ShellIpc {' "$shell"
for surface in 'Drawers {' 'AreaPicker {' 'Background {' 'Shortcuts {'; do
  grep -Fq "$surface" "$shell"
done
if rg -n 'CoreDesktopWindows[[:space:]]*\{|Lock[[:space:]]*\{' "$shell"; then
  printf 'FAIL: reduced core or decorative lock must not be active in the modular shell\n' >&2
  exit 1
fi
grep -Fq 'eventSocketPath: Quickshell.env("XDG_RUNTIME_DIR") + "/sleepy/desktop.sock"' \
  "$repo_root/src/services/DesktopClient.qml"
grep -Fq 'controlSocketPath: Quickshell.env("XDG_RUNTIME_DIR") + "/sleepy/desktop-control.sock"' \
  "$repo_root/src/services/DesktopClient.qml"
grep -Fq 'generation: DesktopClient.generation' "$repo_root/src/services/CommandClient.qml"
grep -Fq '"schemaVersion": 3' "$repo_root/src/services/DesktopCommandProtocol.qml"
grep -Fq '"expectedGeneration": root.generation' "$repo_root/src/services/DesktopCommandProtocol.qml"
if rg -n 'QuickSettings(View|Drawer)' "$repo_root/tests/qml"; then
  printf 'FAIL: compatibility tests must exercise the real Control Center\n' >&2
  exit 1
fi

for forbidden in 'sh -c' 'bash -c' 'quickshell ipc'; do
  if rg -n -F "$forbidden" "$repo_root/src"; then
    printf 'FAIL: shell-string IPC or command interpolation found: %s\n' "$forbidden" >&2
    exit 1
  fi
done

printf 'PASS: typed sleepy IPC boundary and argv-only routing are present\n'
