#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$repo_root/tests/lib/process-state.sh"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/sleepy-wayland-supervisor.XXXXXX")"
wrapper_source="${SLEEPY_PRIVATE_WAYLAND_SOURCE:-$repo_root/tests/with-private-wayland.sh}"
term_pid_file="$test_root/term-compositor.pid"
term_child_pid_file="$test_root/term-child.pid"
term_root_file="$test_root/term-root"
timeout_pid_file="$test_root/timeout-compositor.pid"
timeout_child_pid_file="$test_root/timeout-child.pid"
timeout_root_file="$test_root/timeout-root"

cleanup() {
    for pid_path in "$term_child_pid_file" "$term_pid_file" \
            "$timeout_child_pid_file" "$timeout_pid_file"; do
        if [[ -s "$pid_path" ]]; then
            leaked_pid="$(<"$pid_path")"
            kill "$leaked_pid" 2>/dev/null || true
            wait "$leaked_pid" 2>/dev/null || true
        fi
    done
    for root_file in "$term_root_file" "$timeout_root_file"; do
        if [[ -s "$root_file" ]]; then
            private_root="$(<"$root_file")"
            [[ -n "$private_root" ]] && rm -rf -- "$private_root"
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
sed -i "1c#!$(command -v python3)" "$fake_compositor"
chmod 0700 "$fake_compositor"

hold_probe="$test_root/hold-child"
cat >"$hold_probe" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$SLEEPY_PRIVATE_WAYLAND_ROOT" >"$SLEEPY_TEST_ROOT_FILE"
printf '%s\n' "$$" >"$SLEEPY_TEST_HOLD_PID_FILE"
exec sleep 300
SH
sed -i "1c#!$BASH" "$hold_probe"
chmod 0700 "$hold_probe"

wait_for_probe() {
    local root_file="$1"
    local compositor_file="$2"
    local child_file="$3"
    for _ in $(seq 1 200); do
        [[ -s "$root_file" && -s "$compositor_file" && -s "$child_file" ]] && return 0
        sleep 0.025
    done
    return 1
}

assert_session_cleaned() {
    local label="$1"
    local root_file="$2"
    shift 2
    local private_root
    private_root="$(<"$root_file")"
    for _ in $(seq 1 100); do
        if [[ ! -e "$private_root" ]]; then
            all_dead=true
            for pid_path in "$@"; do
                leaked_pid="$(<"$pid_path")"
                if sleepy_pid_is_running "$leaked_pid"; then
                    all_dead=false
                    break
                fi
            done
            [[ "$all_dead" == true ]] && return 0
        fi
        sleep 0.02
    done
    printf 'FAIL: %s did not remove its private root and reap all descendants\n' "$label" >&2
    exit 1
}

SLEEPY_TEST_WAYLAND_COMPOSITOR="$fake_compositor" \
SLEEPY_TEST_COMPOSITOR_PID_FILE="$term_pid_file" \
SLEEPY_TEST_ROOT_FILE="$term_root_file" \
SLEEPY_TEST_HOLD_PID_FILE="$term_child_pid_file" \
SLEEPY_PRIVATE_WAYLAND_TIMEOUT_SECONDS=20 \
    bash "$wrapper_source" "$hold_probe" &
term_supervisor_pid=$!
if ! wait_for_probe "$term_root_file" "$term_pid_file" "$term_child_pid_file"; then
    kill -TERM "$term_supervisor_pid" 2>/dev/null || true
    wait "$term_supervisor_pid" 2>/dev/null || true
    printf 'FAIL: TERM cleanup probe did not start\n' >&2
    exit 1
fi
kill -TERM "$term_supervisor_pid"
set +e
wait "$term_supervisor_pid"
term_status=$?
set -e
if [[ $term_status -ne 143 ]]; then
    printf 'FAIL: private Wayland supervisor reported %s instead of 143 after TERM\n' \
        "$term_status" >&2
    exit 1
fi
assert_session_cleaned TERM "$term_root_file" "$term_pid_file" "$term_child_pid_file"

timeout_started=$SECONDS
set +e
SLEEPY_TEST_WAYLAND_COMPOSITOR="$fake_compositor" \
SLEEPY_TEST_COMPOSITOR_PID_FILE="$timeout_pid_file" \
SLEEPY_TEST_ROOT_FILE="$timeout_root_file" \
SLEEPY_TEST_HOLD_PID_FILE="$timeout_child_pid_file" \
SLEEPY_PRIVATE_WAYLAND_TIMEOUT_SECONDS=1 \
    bash "$wrapper_source" "$hold_probe" >/dev/null 2>&1
timeout_status=$?
set -e
timeout_elapsed=$((SECONDS - timeout_started))
if [[ $timeout_status -ne 124 || $timeout_elapsed -ge 8 ]]; then
    printf 'FAIL: private Wayland supervisor timeout was not bounded (status=%s elapsed=%ss)\n' \
        "$timeout_status" "$timeout_elapsed" >&2
    exit 1
fi
assert_session_cleaned timeout "$timeout_root_file" \
    "$timeout_pid_file" "$timeout_child_pid_file"

printf 'PASS: private Wayland supervisor handles TERM and bounded timeout with full cleanup\n'
