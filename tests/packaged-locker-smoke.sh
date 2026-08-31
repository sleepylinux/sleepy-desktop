#!/usr/bin/env bash
set -euo pipefail

locker_executable="${1:-}"
if [[ -z "$locker_executable" || ! -x "$locker_executable" ]]; then
    printf 'FAIL: packaged locker smoke requires the packaged executable\n' >&2
    exit 1
fi
if [[ -z "${WAYLAND_DISPLAY:-}" || -z "${XDG_RUNTIME_DIR:-}" \
        || ! -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]]; then
    printf 'FAIL: packaged locker smoke requires the private Wayland socket\n' >&2
    exit 1
fi

smoke_root="$(mktemp -d "${TMPDIR:-/tmp}/sleepy-locker-smoke.XXXXXX")"
smoke_log="$smoke_root/locker.log"
locker_pid=""
cleanup() {
    if [[ -n "$locker_pid" ]] && kill -0 "$locker_pid" 2>/dev/null; then
        kill -TERM "$locker_pid" 2>/dev/null || true
        for _ in $(seq 1 40); do
            kill -0 "$locker_pid" 2>/dev/null || break
            sleep 0.05
        done
        kill -KILL "$locker_pid" 2>/dev/null || true
        wait "$locker_pid" 2>/dev/null || true
    fi
    rm -rf -- "$smoke_root"
}
trap cleanup EXIT

QT_QPA_PLATFORM=wayland "$locker_executable" >"$smoke_log" 2>&1 &
locker_pid=$!
locker_socket="$XDG_RUNTIME_DIR/sleepy/locker.sock"
for _ in $(seq 1 100); do
    [[ -S "$locker_socket" ]] && break
    if ! kill -0 "$locker_pid" 2>/dev/null; then
        cat "$smoke_log" >&2
        printf 'FAIL: packaged locker exited before publishing its endpoint\n' >&2
        exit 1
    fi
    sleep 0.05
done
[[ -S "$locker_socket" ]] || {
    cat "$smoke_log" >&2
    printf 'FAIL: packaged locker did not publish its endpoint\n' >&2
    exit 1
}

python3 - "$locker_socket" <<'PY'
import socket
import sys

client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
client.settimeout(10)
client.connect(sys.argv[1])
client.sendall(b"lock\n")
reply = client.recv(64)
if reply != b"locked\n":
    raise SystemExit(f"unexpected locker acknowledgement: {reply!r}")
PY

cat "$smoke_log"
if grep -Fq 'Failed to load configuration' "$smoke_log" || \
    grep -Fq 'is not a type' "$smoke_log" || \
    grep -Eq 'module ".*" is not installed' "$smoke_log"; then
    printf 'FAIL: packaged locker failed to load its secure QML graph\n' >&2
    exit 1
fi

printf 'PASS: packaged locker covered both private outputs and acknowledged secure lock\n'
