#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/sleepy-wayland-contract.XXXXXX")"
pid_file="$test_root/compositor.pid"
child_pid_file="$test_root/child.pid"

cleanup() {
    for pid_path in "$child_pid_file" "$pid_file"; do
        if [[ -s "$pid_path" ]]; then
            leaked_pid="$(<"$pid_path")"
            kill "$leaked_pid" 2>/dev/null || true
            wait "$leaked_pid" 2>/dev/null || true
        fi
    done
    rm -rf -- "$test_root"
}
trap cleanup EXIT

fake_compositor="$test_root/sway"
cat >"$fake_compositor" <<'PY'
#!/usr/bin/env python3
import os
import signal
import socket

for inherited_name in (
    "WAYLAND_DISPLAY",
    "WAYLAND_SOCKET",
    "HYPRLAND_INSTANCE_SIGNATURE",
    "SWAYSOCK",
    "I3SOCK",
    "DISPLAY",
):
    if inherited_name in os.environ:
        raise SystemExit(f"inherited compositor state: {inherited_name}")

socket_path = os.path.join(os.environ["XDG_RUNTIME_DIR"], "wayland-contract")
server = socket.socket(socket.AF_UNIX)
server.bind(socket_path)
server.listen(1)
with open(os.environ["SLEEPY_TEST_COMPOSITOR_PID_FILE"], "w", encoding="utf-8") as handle:
    handle.write(str(os.getpid()))

def stop(_signum, _frame):
    raise SystemExit(0)

signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)
signal.pause()
PY
chmod 0700 "$fake_compositor"

real_home="$test_root/real-home"
real_cache="$test_root/real-cache"
real_config="$test_root/real-config"
real_data="$test_root/real-data"
real_state="$test_root/real-state"
mkdir -p "$real_home" "$real_cache" "$real_config" "$real_data" "$real_state"

observed_file="$test_root/private-paths"
child_probe="$test_root/assert-private-child"
cat >"$child_probe" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

for inherited_name in WAYLAND_SOCKET HYPRLAND_INSTANCE_SIGNATURE SWAYSOCK I3SOCK DISPLAY; do
    if [[ -n "${!inherited_name:-}" ]]; then
        printf 'inherited compositor state: %s\n' "$inherited_name" >&2
        exit 1
    fi
done

[[ -n "${SLEEPY_PRIVATE_WAYLAND_ROOT:-}" ]]
[[ -n "${SLEEPY_PRIVATE_WAYLAND_GUARD:-}" ]]
[[ ! -L "$SLEEPY_PRIVATE_WAYLAND_GUARD" ]]
[[ -f "$SLEEPY_PRIVATE_WAYLAND_GUARD" ]]
[[ "$(dirname -- "$SLEEPY_PRIVATE_WAYLAND_GUARD")" == "$XDG_RUNTIME_DIR" ]]
[[ "$(<"$SLEEPY_PRIVATE_WAYLAND_GUARD")" == "$XDG_RUNTIME_DIR" ]]
[[ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]]

for private_path in \
    "$SLEEPY_PRIVATE_WAYLAND_ROOT" "$XDG_RUNTIME_DIR" "$HOME" \
    "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME"; do
    [[ -d "$private_path" ]]
    [[ "$private_path" == "$SLEEPY_PRIVATE_WAYLAND_ROOT"/* \
        || "$private_path" == "$SLEEPY_PRIVATE_WAYLAND_ROOT" ]]
done
[[ "$HOME" != "$SLEEPY_TEST_REAL_HOME" ]]
[[ "$XDG_CACHE_HOME" != "$SLEEPY_TEST_REAL_CACHE" ]]
[[ "$XDG_CONFIG_HOME" != "$SLEEPY_TEST_REAL_CONFIG" ]]
[[ "$XDG_DATA_HOME" != "$SLEEPY_TEST_REAL_DATA" ]]
[[ "$XDG_STATE_HOME" != "$SLEEPY_TEST_REAL_STATE" ]]

printf 'root=%s\nruntime=%s\nhome=%s\ncache=%s\nconfig=%s\ndata=%s\nstate=%s\n' \
    "$SLEEPY_PRIVATE_WAYLAND_ROOT" "$XDG_RUNTIME_DIR" "$HOME" \
    "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" \
    >"$SLEEPY_TEST_OBSERVED_FILE"
mkdir -p "$XDG_CACHE_HOME/quickshell/crashes" "$HOME/.cache/quickshell/crashes"
: >"$XDG_CACHE_HOME/quickshell/crashes/contract-crash.log"
: >"$HOME/.cache/quickshell/crashes/contract-crash.log"
sleep 300 &
printf '%s\n' "$!" >"$SLEEPY_TEST_CHILD_PID_FILE"
exit 23
SH
chmod 0700 "$child_probe"

set +e
SLEEPY_TEST_WAYLAND_COMPOSITOR="$fake_compositor" \
SLEEPY_TEST_COMPOSITOR_PID_FILE="$pid_file" \
SLEEPY_TEST_CHILD_PID_FILE="$child_pid_file" \
SLEEPY_TEST_OBSERVED_FILE="$observed_file" \
SLEEPY_TEST_REAL_HOME="$real_home" \
SLEEPY_TEST_REAL_CACHE="$real_cache" \
SLEEPY_TEST_REAL_CONFIG="$real_config" \
SLEEPY_TEST_REAL_DATA="$real_data" \
SLEEPY_TEST_REAL_STATE="$real_state" \
SLEEPY_PRIVATE_WAYLAND_TIMEOUT_SECONDS=20 \
HOME="$real_home" \
XDG_CACHE_HOME="$real_cache" \
XDG_CONFIG_HOME="$real_config" \
XDG_DATA_HOME="$real_data" \
XDG_STATE_HOME="$real_state" \
WAYLAND_DISPLAY=live-wayland \
WAYLAND_SOCKET=999 \
HYPRLAND_INSTANCE_SIGNATURE=live-hyprland \
SWAYSOCK=/live/sway.sock \
I3SOCK=/live/i3.sock \
DISPLAY=:99 \
    bash "$repo_root/tests/with-private-wayland.sh" \
        "$child_probe"
status=$?
set -e

if [[ $status -ne 23 ]]; then
    printf 'FAIL: private Wayland runner masked child status 23 as %s\n' "$status" >&2
    exit 1
fi
if [[ ! -s "$pid_file" ]]; then
    printf 'FAIL: private Wayland runner did not start the isolated compositor\n' >&2
    exit 1
fi
compositor_pid="$(<"$pid_file")"
if kill -0 "$compositor_pid" 2>/dev/null; then
    printf 'FAIL: private Wayland runner left compositor process %s alive\n' \
        "$compositor_pid" >&2
    exit 1
fi
if [[ ! -s "$child_pid_file" ]]; then
    printf 'FAIL: private Wayland runner did not execute the isolated child probe\n' >&2
    exit 1
fi
child_pid="$(<"$child_pid_file")"
if kill -0 "$child_pid" 2>/dev/null; then
    printf 'FAIL: private Wayland runner left test process %s alive\n' "$child_pid" >&2
    exit 1
fi

if [[ -e "$real_cache/quickshell/crashes/contract-crash.log" \
    || -e "$real_home/.cache/quickshell/crashes/contract-crash.log" ]]; then
    printf 'FAIL: child wrote a Quickshell-style crash artifact under the inherited user state\n' >&2
    exit 1
fi
if [[ ! -s "$observed_file" ]]; then
    printf 'FAIL: child did not report its private HOME/XDG locations\n' >&2
    exit 1
fi
while IFS='=' read -r _ private_path; do
    if [[ -e "$private_path" ]]; then
        printf 'FAIL: private Wayland runner did not remove isolated path %s\n' \
            "$private_path" >&2
        exit 1
    fi
done <"$observed_file"

if ! rg -Fq 'tests/with-private-wayland.sh' "$repo_root/tests/run.sh"; then
    printf 'FAIL: full test runner must route real Quickshell host tests through private Wayland\n' >&2
    exit 1
fi
if rg -q -e '^[[:space:]]*bash "\$repo_root/tests/quickshell-core-host\.sh"' \
        "$repo_root/tests/run.sh"; then
    printf 'FAIL: full test runner directly targets the inherited Wayland session\n' >&2
    exit 1
fi
if ! rg -Fq 'SKIP: private Wayland compositor is not configured' \
        "$repo_root/tests/run.sh"; then
    printf 'FAIL: full test runner must skip the host gate when no private compositor is declared\n' >&2
    exit 1
fi
if ! rg -Fq 'export QT_QPA_PLATFORM=offscreen' "$repo_root/tests/run.sh"; then
    printf 'FAIL: QML behavior tests must force the offscreen platform\n' >&2
    exit 1
fi

printf 'PASS: private Wayland runner isolates compositor and user state, propagates status, and reaps its process group\n'
