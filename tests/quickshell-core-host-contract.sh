#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/sleepy-qs-contract.XXXXXX")"
socket_pid=""

cleanup() {
    if [[ -n "$socket_pid" ]]; then
        kill "$socket_pid" 2>/dev/null || true
        wait "$socket_pid" 2>/dev/null || true
    fi
    rm -rf -- "$test_root"
}
trap cleanup EXIT

mkdir -p "$test_root/runtime" "$test_root/bin" \
    "$test_root/sdk/fixtures/desktop-runtime" \
    "$test_root/repository/tests/fixtures"
chmod 0700 "$test_root/runtime"

python3 - "$test_root/runtime/test-wayland" <<'PY' &
import signal
import socket
import sys

server = socket.socket(socket.AF_UNIX)
server.bind(sys.argv[1])
server.listen(1)
signal.pause()
PY
socket_pid=$!
for _ in $(seq 1 50); do
    [[ -S "$test_root/runtime/test-wayland" ]] && break
    sleep 0.02
done
test -S "$test_root/runtime/test-wayland"

printf '#!/usr/bin/env bash\nprintf "TASK7B_HOST_PASS\\n"\n' \
    >"$test_root/bin/quickshell"
chmod 0700 "$test_root/bin/quickshell"

cp "$repo_root/tests/fixtures/task7b-sdk-full-snapshot.json" \
    "$test_root/sdk/fixtures/desktop-runtime/full-snapshot.json"
cp "$repo_root/tests/fixtures/task7b-sdk-full-snapshot.json" \
    "$test_root/repository/tests/fixtures/task7b-sdk-full-snapshot.json"
cp "$repo_root/tests/quickshell-core-host.sh" \
    "$test_root/repository/tests/quickshell-core-host.sh"

PATH="$test_root/bin:$PATH" \
    XDG_RUNTIME_DIR="$test_root/runtime" WAYLAND_DISPLAY=test-wayland \
    SLEEPY_SDK_ROOT="$test_root/sdk" \
    bash "$test_root/repository/tests/quickshell-core-host.sh" software

printf 'PASS: host gate resolves and validates the supplied SDK root\n'
