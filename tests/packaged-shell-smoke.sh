#!/usr/bin/env bash
set -euo pipefail

shell_executable="${1:-}"
if [[ -z "$shell_executable" || ! -x "$shell_executable" ]]; then
    printf 'FAIL: packaged shell smoke requires the packaged executable\n' >&2
    exit 1
fi
if [[ -z "${WAYLAND_DISPLAY:-}" || -z "${XDG_RUNTIME_DIR:-}" \
        || ! -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]]; then
    printf 'FAIL: packaged shell smoke requires the private Wayland socket\n' >&2
    exit 1
fi

smoke_root="$(mktemp -d "${TMPDIR:-/tmp}/sleepy-package-smoke.XXXXXX")"
smoke_log="$smoke_root/shell.log"
cleanup() {
    rm -rf -- "$smoke_root"
}
trap cleanup EXIT

set +e
QT_QPA_PLATFORM=wayland \
timeout --signal=TERM --kill-after=5s 5 \
    "$shell_executable" >"$smoke_log" 2>&1
status=$?
set -e
cat "$smoke_log"

if grep -Fq 'Failed to load configuration' "$smoke_log" || \
    grep -Fq 'is not a type' "$smoke_log" || \
    grep -Fq 'ReferenceError:' "$smoke_log" || \
    grep -Fq 'TypeError:' "$smoke_log" || \
    grep -Fq 'SyntaxError:' "$smoke_log" || \
    grep -Eq 'module ".*" is not installed' "$smoke_log" || \
    grep -Fq 'QQmlApplicationEngine failed' "$smoke_log"; then
    printf 'FAIL: packaged production shell failed to load its QML graph\n' >&2
    exit 1
fi
if [[ $status -ne 124 ]]; then
    printf 'FAIL: packaged production shell exited unexpectedly with status %s\n' \
        "$status" >&2
    exit 1
fi

printf 'PASS: packaged production shell remained healthy on private Wayland\n'
