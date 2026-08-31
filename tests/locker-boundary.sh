#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
locker="$repo_root/locker"
flake="$repo_root/flake.nix"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

for path in \
  "$locker/CMakeLists.txt" \
  "$locker/main.cpp" \
  "$locker/secureprompt.hpp" \
  "$locker/secureprompt.cpp" \
  "$locker/qml/LockRoot.qml" \
  "$repo_root/tests/packaged-locker-smoke.sh" \
  "$repo_root/tests/locker_native.cpp"; do
  [[ -f "$path" ]] || fail "missing locker source: ${path#"$repo_root/"}"
done

rg -Fq 'Q_PROPERTY(int inputLength' "$locker/secureprompt.hpp" \
  || fail 'QML may observe only the native input length'
rg -Fq 'Q_PROPERTY(AuthState authState' "$locker/secureprompt.hpp" \
  || fail 'QML must receive a redacted authentication state'
if rg -n 'Q_PROPERTY\([^)]*(password|secret|text|buffer)|QString[[:space:]]+(password|secret|buffer)_' \
    "$locker/secureprompt.hpp" "$locker/secureprompt.cpp"; then
  fail 'plaintext credentials must never be a QML property or persistent QString'
fi

rg -Fq 'mlock(' "$locker/secureprompt.cpp" \
  || fail 'native credential storage must request locked memory'
rg -Fq 'explicit_bzero(' "$locker/secureprompt.cpp" \
  || fail 'native credential storage must explicitly zeroize'
for exit_path in submit cancel failure destruction shutdown; do
  rg -Fq "ZEROIZE_${exit_path^^}" "$locker/secureprompt.cpp" \
    || fail "missing auditable zeroization marker for $exit_path"
done

rg -Fq 'WlSessionLock' "$locker/qml/LockRoot.qml" \
  || fail 'locker must own ext-session-lock through Quickshell WlSessionLock'
rg -Fq 'WlSessionLockSurface' "$locker/qml/LockRoot.qml" \
  || fail 'locker must create a lock surface for every compositor output'
rg -Fq 'secure' "$locker/qml/LockRoot.qml" \
  || fail 'locked acknowledgement must be driven by secure session-lock state'

if rg -n '\b(unlock|Unlock)\b' "$locker" \
    | rg -v 'PAM result|authenticated|unlock-and-destroy|sessionLock\.unlock\(\)'; then
  fail 'locker must not expose a public or generic unlock path'
fi
if rg -n '(IpcHandler|CustomShortcut|GlobalShortcut)' "$locker"; then
  fail 'locker must not expose Quickshell IPC or shortcut authority'
fi

rg -Fq 'SO_PEERCRED' "$locker/main.cpp" \
  || fail 'locker request endpoint must authenticate its local peer'
rg -Fq 'lock' "$locker/main.cpp" \
  || fail 'locker endpoint must accept a lock request'
rg -Fq 'locked' "$locker/main.cpp" \
  || fail 'locker endpoint must acknowledge only confirmed secure state'
rg -Fq 'URI Sleepy.Locker.Native' "$locker/CMakeLists.txt" \
  || fail 'native secure prompt and endpoint must be a dedicated QML plugin'
if rg -Fq 'QQmlApplicationEngine' "$locker/main.cpp"; then
  fail 'standalone Qt engines cannot load Quickshell static Wayland modules'
fi
rg -Fq 'runner = "${quickshellWithModules}/bin/qs"' "$flake" \
  || fail 'locker must run inside the pinned Quickshell engine'
rg -Fq 'LockRoot.qml' "$flake" \
  || fail 'packaged locker must start only its immutable lock configuration'
rg -Fq 'packaged-locker-smoke.sh' "$flake" \
  || fail 'Nix gate must acquire a real lock on the private two-output compositor'
rg -Fq 'sleepy-locker = lockerPackage;' "$flake" \
  || fail 'flake must export the dedicated sleepy-locker package'
rg -Fq 'quickShellWithModules' "$flake" 2>/dev/null \
  && fail 'locker package must use the reviewed quickshellWithModules value exactly'
rg -Fq 'quickshellWithModules' "$flake" \
  || fail 'locker package must carry the reviewed Quickshell Wayland module'

printf 'PASS: fail-secure locker source boundary\n'
