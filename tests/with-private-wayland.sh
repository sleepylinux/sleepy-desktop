#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--session" ]]; then
    shift
    runner_root="$1"
    compositor="$2"
    compositor_config="$3"
    compositor_log="$4"
    shift 4

    runtime_dir="$runner_root/runtime"
    private_home="$runner_root/home"
    private_cache="$runner_root/cache"
    private_config="$runner_root/config"
    private_data="$runner_root/data"
    private_state="$runner_root/state"
    private_guard="$runtime_dir/.sleepy-private-wayland.guard"

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

    env -u WAYLAND_DISPLAY -u WAYLAND_SOCKET -u DISPLAY -u XAUTHORITY \
        -u HYPRLAND_INSTANCE_SIGNATURE -u SWAYSOCK -u I3SOCK \
        HOME="$private_home" XDG_RUNTIME_DIR="$runtime_dir" \
        XDG_CACHE_HOME="$private_cache" XDG_CONFIG_HOME="$private_config" \
        XDG_DATA_HOME="$private_data" XDG_STATE_HOME="$private_state" \
        SLEEPY_PRIVATE_WAYLAND_ROOT="$runner_root" \
        SLEEPY_PRIVATE_WAYLAND_GUARD="$private_guard" \
        WLR_BACKENDS=headless \
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

    export HOME="$private_home"
    export XDG_RUNTIME_DIR="$runtime_dir"
    export XDG_CACHE_HOME="$private_cache"
    export XDG_CONFIG_HOME="$private_config"
    export XDG_DATA_HOME="$private_data"
    export XDG_STATE_HOME="$private_state"
    export SLEEPY_PRIVATE_WAYLAND_ROOT="$runner_root"
    export SLEEPY_PRIVATE_WAYLAND_GUARD="$private_guard"
    export WAYLAND_DISPLAY="$wayland_socket"
    unset WAYLAND_SOCKET HYPRLAND_INSTANCE_SIGNATURE SWAYSOCK I3SOCK
    unset DISPLAY XAUTHORITY
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

runner_root=""
session_pid=""
session_pgid=""
owns_session_group=false
cleanup_session() {
    if [[ "$owns_session_group" == true && -n "$session_pgid" ]]; then
        if kill -0 -- "-$session_pgid" 2>/dev/null; then
            kill -TERM -- "-$session_pgid" 2>/dev/null || true
            for _ in $(seq 1 40); do
                kill -0 -- "-$session_pgid" 2>/dev/null || break
                sleep 0.05
            done
            kill -KILL -- "-$session_pgid" 2>/dev/null || true
        fi
    elif [[ -n "$session_pid" ]] && kill -0 "$session_pid" 2>/dev/null; then
        kill -TERM "$session_pid" 2>/dev/null || true
    fi
    if [[ -n "$session_pid" ]]; then
        wait "$session_pid" 2>/dev/null || true
    fi
    if [[ -n "$runner_root" ]]; then
        rm -rf -- "$runner_root"
    fi
}
runner_root="$(mktemp -d "${TMPDIR:-/tmp}/sleepy-private-wayland.XXXXXX")"
trap cleanup_session EXIT
trap 'exit 143' TERM
trap 'exit 130' INT

runtime_dir="$runner_root/runtime"
private_home="$runner_root/home"
private_cache="$runner_root/cache"
private_config="$runner_root/config"
private_data="$runner_root/data"
private_state="$runner_root/state"
private_guard="$runtime_dir/.sleepy-private-wayland.guard"
compositor_config="$runner_root/sway.conf"
compositor_log="$runner_root/sway.log"
mkdir -p "$runtime_dir" "$private_home" "$private_cache" "$private_config" \
    "$private_data" "$private_state"
chmod 0700 "$runner_root" "$runtime_dir" "$private_home" "$private_cache" \
    "$private_config" "$private_data" "$private_state"
printf '%s\n' "$runtime_dir" >"$private_guard"
chmod 0600 "$private_guard"
printf 'xwayland disable\nseat seat0 fallback true\noutput * resolution 1280x720\n' \
    >"$compositor_config"

unset WAYLAND_DISPLAY WAYLAND_SOCKET HYPRLAND_INSTANCE_SIGNATURE SWAYSOCK I3SOCK
unset DISPLAY XAUTHORITY SLEEPY_PRIVATE_WAYLAND_ROOT SLEEPY_PRIVATE_WAYLAND_GUARD
setsid timeout --signal=TERM --kill-after=5s "$timeout_seconds" \
    dbus-run-session -- bash "$0" --session \
        "$runner_root" "$compositor" "$compositor_config" "$compositor_log" \
        "$@" &
session_pid=$!
session_pgid="$session_pid"
owns_session_group=true

set +e
wait "$session_pid"
status=$?
set -e
if [[ $status -ne 0 ]]; then
    cat "$compositor_log" >&2
fi
cleanup_session
trap - EXIT
exit "$status"
