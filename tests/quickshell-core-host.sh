#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
sdk_root="${SLEEPY_SDK_ROOT:-$(cd "$repo_root/../sleepy-sdk" && pwd -P)}"
backend="${1:-software}"
case "$backend" in
    software|rhi) ;;
    *) printf 'FAIL: quickshell host backend must be software or rhi\n' >&2; exit 1 ;;
esac
quickshell="${2:-}"
if [[ -z "$quickshell" || "$quickshell" != /* \
        || ! -f "$quickshell" || ! -x "$quickshell" ]]; then
    printf 'FAIL: production CoreDesktopWindows test requires an explicit executable Quickshell path\n' >&2
    exit 1
fi

private_guard="${SLEEPY_PRIVATE_WAYLAND_GUARD:-}"
if [[ -z "${XDG_RUNTIME_DIR:-}" || -z "$private_guard" \
        || "$private_guard" != "$XDG_RUNTIME_DIR/.sleepy-private-wayland.guard" \
        || -L "$private_guard" || ! -f "$private_guard" \
        || "$(<"$private_guard")" != "$XDG_RUNTIME_DIR" ]]; then
    printf 'FAIL: production CoreDesktopWindows test requires the private Wayland runner guard\n' >&2
    exit 1
fi

if [[ -z "${WAYLAND_DISPLAY:-}" || -z "${XDG_RUNTIME_DIR:-}" \
        || ! -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]]; then
    printf 'FAIL: production CoreDesktopWindows test requires a Quickshell-capable Wayland compositor\n' >&2
    exit 1
fi

if ! cmp -s "$repo_root/tests/fixtures/task7b-sdk-full-snapshot.json" \
        "$sdk_root/fixtures/desktop-runtime/full-snapshot.json"; then
    printf 'FAIL: Task 7b host fixture must exactly mirror the authoritative SDK full snapshot\n' >&2
    exit 1
fi

runtime_dir="$(mktemp -d "${TMPDIR:-/tmp}/sleepy-qs-host.XXXXXX")"
host_log="$runtime_dir/host.log"
runner_pid=""
runner_pgid=""
owns_runner_group=false

cleanup() {
    if [[ "$owns_runner_group" == true && -n "$runner_pgid" ]] \
            && kill -0 -- "-$runner_pgid" 2>/dev/null; then
        kill -TERM -- "-$runner_pgid" 2>/dev/null || true
        for _ in $(seq 1 20); do
            kill -0 -- "-$runner_pgid" 2>/dev/null || break
            sleep 0.05
        done
        kill -KILL -- "-$runner_pgid" 2>/dev/null || true
    fi
    if [[ -n "$runner_pid" ]]; then
        wait "$runner_pid" 2>/dev/null || true
    fi
    rm -rf -- "$runtime_dir"
}
trap cleanup EXIT

setsid env QML_XHR_ALLOW_FILE_READ=1 QT_QPA_PLATFORM=wayland \
    QT_QUICK_BACKEND="$backend" QSG_RHI_BACKEND=opengl LIBGL_ALWAYS_SOFTWARE=1 \
    timeout --signal=TERM --kill-after=5s 45s \
    "$quickshell" --no-color --path \
        "$repo_root/tst_core_desktop_windows.qml" \
        >"$host_log" 2>&1 &
runner_pid=$!
runner_pgid="$runner_pid"
owns_runner_group=true

set +e
wait "$runner_pid"
runner_status=$?
set -e
if [[ $runner_status -ne 0 ]]; then
    cat "$host_log" >&2
    exit 1
fi

if ! rg -Fq 'TASK7B_HOST_PASS' "$host_log"; then
    cat "$host_log" >&2
    printf 'FAIL: production Quickshell host did not report completion\n' >&2
    exit 1
fi

printf 'PASS: production CoreDesktopWindows real PanelWindow lifecycle (%s)\n' "$backend"
