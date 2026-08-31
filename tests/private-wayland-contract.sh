#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/sleepy-wayland-contract.XXXXXX")"

cleanup() {
    rm -rf -- "$test_root"
}
trap cleanup EXIT

fake_compositor="$test_root/sway"
pid_file="$test_root/compositor.pid"
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

set +e
SLEEPY_TEST_WAYLAND_COMPOSITOR="$fake_compositor" \
SLEEPY_TEST_COMPOSITOR_PID_FILE="$pid_file" \
SLEEPY_PRIVATE_WAYLAND_TIMEOUT_SECONDS=20 \
WAYLAND_DISPLAY=live-wayland \
WAYLAND_SOCKET=999 \
HYPRLAND_INSTANCE_SIGNATURE=live-hyprland \
SWAYSOCK=/live/sway.sock \
I3SOCK=/live/i3.sock \
    bash "$repo_root/tests/with-private-wayland.sh" \
        bash -c 'test -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"; test -z "${WAYLAND_SOCKET:-}"; test -z "${HYPRLAND_INSTANCE_SIGNATURE:-}"; test -z "${SWAYSOCK:-}"; test -z "${I3SOCK:-}"; exit 23'
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

printf 'PASS: private Wayland runner isolates the socket, propagates status, and cleans up\n'
