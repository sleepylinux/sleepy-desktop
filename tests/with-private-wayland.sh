#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--session" ]]; then
    shift
    runtime_dir="$1"
    compositor="$2"
    compositor_config="$3"
    compositor_log="$4"
    shift 4

    compositor_pid=""
    cleanup_compositor() {
        if [[ -n "$compositor_pid" ]] && kill -0 "$compositor_pid" 2>/dev/null; then
            kill -TERM "$compositor_pid" 2>/dev/null || true
            for _ in $(seq 1 40); do
                kill -0 "$compositor_pid" 2>/dev/null || break
                sleep 0.05
            done
            kill -KILL "$compositor_pid" 2>/dev/null || true
            wait "$compositor_pid" 2>/dev/null || true
        fi
    }
    trap cleanup_compositor EXIT
    trap 'exit 143' TERM
    trap 'exit 130' INT

    env -u WAYLAND_DISPLAY -u WAYLAND_SOCKET -u DISPLAY \
        -u HYPRLAND_INSTANCE_SIGNATURE -u SWAYSOCK -u I3SOCK \
        XDG_RUNTIME_DIR="$runtime_dir" WLR_BACKENDS=headless \
        WLR_HEADLESS_OUTPUTS=2 WLR_LIBINPUT_NO_DEVICES=1 WLR_RENDERER=pixman \
        "$compositor" --unsupported-gpu --config "$compositor_config" \
            --verbose >"$compositor_log" 2>&1 &
    compositor_pid=$!

    wayland_socket=""
    for _ in $(seq 1 200); do
        for candidate in "$runtime_dir"/wayland-*; do
            if [[ -S "$candidate" ]]; then
                wayland_socket="${candidate##*/}"
                break 2
            fi
        done
        if ! kill -0 "$compositor_pid" 2>/dev/null; then
            cat "$compositor_log" >&2
            printf 'FAIL: private Wayland compositor exited before publishing its socket\n' >&2
            exit 1
        fi
        sleep 0.05
    done
    if [[ -z "$wayland_socket" ]]; then
        cat "$compositor_log" >&2
        printf 'FAIL: private Wayland compositor did not publish its socket\n' >&2
        exit 1
    fi

    export XDG_RUNTIME_DIR="$runtime_dir"
    export WAYLAND_DISPLAY="$wayland_socket"
    unset WAYLAND_SOCKET HYPRLAND_INSTANCE_SIGNATURE SWAYSOCK I3SOCK
    set +e
    "$@"
    child_status=$?
    set -e
    exit "$child_status"
fi

if [[ $# -eq 0 ]]; then
    printf 'FAIL: private Wayland runner requires a command\n' >&2
    exit 1
fi

compositor="${SLEEPY_TEST_WAYLAND_COMPOSITOR:-${SLEEPY_TEST_SWAY:-}}"
if [[ -z "$compositor" || ! -x "$compositor" ]]; then
    printf 'FAIL: SLEEPY_TEST_WAYLAND_COMPOSITOR must name the declared Sway executable\n' >&2
    exit 1
fi
for required_tool in dbus-run-session setsid timeout; do
    if ! command -v "$required_tool" >/dev/null 2>&1; then
        printf 'FAIL: private Wayland runner requires %s\n' "$required_tool" >&2
        exit 1
    fi
done

timeout_seconds="${SLEEPY_PRIVATE_WAYLAND_TIMEOUT_SECONDS:-180}"
if [[ ! "$timeout_seconds" =~ ^[1-9][0-9]*$ ]]; then
    printf 'FAIL: SLEEPY_PRIVATE_WAYLAND_TIMEOUT_SECONDS must be a positive integer\n' >&2
    exit 1
fi

runner_root="$(mktemp -d "${TMPDIR:-/tmp}/sleepy-private-wayland.XXXXXX")"
runtime_dir="$runner_root/runtime"
compositor_config="$runner_root/sway.conf"
compositor_log="$runner_root/sway.log"
mkdir -p "$runtime_dir"
chmod 0700 "$runtime_dir"
printf 'xwayland disable\nseat seat0 fallback true\noutput * resolution 1280x720\n' \
    >"$compositor_config"

session_pid=""
session_pgid=""
cleanup_session() {
    if [[ -n "$session_pid" ]] && kill -0 "$session_pid" 2>/dev/null; then
        if [[ "$session_pgid" == "$session_pid" ]]; then
            kill -TERM -- "-$session_pgid" 2>/dev/null || true
            for _ in $(seq 1 40); do
                kill -0 "$session_pid" 2>/dev/null || break
                sleep 0.05
            done
            kill -KILL -- "-$session_pgid" 2>/dev/null || true
        else
            kill -TERM "$session_pid" 2>/dev/null || true
        fi
        wait "$session_pid" 2>/dev/null || true
    fi
    rm -rf -- "$runner_root"
}
trap cleanup_session EXIT
trap 'exit 143' TERM
trap 'exit 130' INT

unset WAYLAND_DISPLAY WAYLAND_SOCKET HYPRLAND_INSTANCE_SIGNATURE SWAYSOCK I3SOCK
setsid timeout --signal=TERM --kill-after=5s "$timeout_seconds" \
    dbus-run-session -- bash "$0" --session \
        "$runtime_dir" "$compositor" "$compositor_config" "$compositor_log" \
        "$@" &
session_pid=$!
session_pgid="$(ps -o pgid= -p "$session_pid" | tr -d '[:space:]')"
if [[ "$session_pgid" != "$session_pid" ]]; then
    printf 'FAIL: private Wayland supervisor did not receive its own process group\n' >&2
    exit 1
fi

set +e
wait "$session_pid"
status=$?
set -e
session_pid=""
if [[ $status -ne 0 ]]; then
    cat "$compositor_log" >&2
fi
exit "$status"
