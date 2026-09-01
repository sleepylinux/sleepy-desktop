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

mkdir -p "$test_root/live-runtime" "$test_root/private-runtime" \
    "$test_root/path-bin" "$test_root/explicit-bin" \
    "$test_root/sdk/fixtures/desktop-runtime" \
    "$test_root/repository/tests/fixtures"
chmod 0700 "$test_root/live-runtime" "$test_root/private-runtime"

python3 - "$test_root/live-runtime/test-wayland" \
    "$test_root/private-runtime/test-wayland" <<'PY' &
import signal
import socket
import sys

servers = []
for path in sys.argv[1:]:
    server = socket.socket(socket.AF_UNIX)
    server.bind(path)
    server.listen(1)
    servers.append(server)
signal.pause()
PY
socket_pid=$!
for _ in $(seq 1 50); do
    [[ -S "$test_root/live-runtime/test-wayland" \
        && -S "$test_root/private-runtime/test-wayland" ]] && break
    sleep 0.02
done
test -S "$test_root/live-runtime/test-wayland"
test -S "$test_root/private-runtime/test-wayland"

path_marker="$test_root/path-quickshell-ran"
explicit_marker="$test_root/explicit-quickshell-ran"
cat >"$test_root/path-bin/quickshell" <<'SH'
#!/usr/bin/env bash
: >"$SLEEPY_PATH_MARKER"
printf 'TASK7B_HOST_PASS\n'
SH
chmod 0700 "$test_root/path-bin/quickshell"

cat >"$test_root/explicit-bin/qs" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$0" "$@" >"$SLEEPY_EXPLICIT_MARKER"
printf 'TASK7B_HOST_PASS\n'
SH
chmod 0700 "$test_root/explicit-bin/qs"

non_executable_qs="$test_root/explicit-bin/not-executable-qs"
printf '#!/usr/bin/env bash\nexit 0\n' >"$non_executable_qs"
chmod 0600 "$non_executable_qs"

cp "$repo_root/tests/fixtures/task7b-sdk-full-snapshot.json" \
    "$test_root/sdk/fixtures/desktop-runtime/full-snapshot.json"
cp "$repo_root/tests/fixtures/task7b-sdk-full-snapshot.json" \
    "$test_root/repository/tests/fixtures/task7b-sdk-full-snapshot.json"
cp "$repo_root/tests/quickshell-core-host.sh" \
    "$test_root/repository/tests/quickshell-core-host.sh"

run_host() {
    PATH="$test_root/path-bin:$PATH" \
    SLEEPY_PATH_MARKER="$path_marker" \
    SLEEPY_EXPLICIT_MARKER="$explicit_marker" \
    SLEEPY_SDK_ROOT="$test_root/sdk" \
        "$@"
}

set +e
run_host env XDG_RUNTIME_DIR="$test_root/live-runtime" \
    WAYLAND_DISPLAY=test-wayland \
    bash "$test_root/repository/tests/quickshell-core-host.sh" software \
        "$test_root/explicit-bin/qs" >/dev/null 2>&1
live_status=$?
set -e
if [[ $live_status -eq 0 || -e "$path_marker" || -e "$explicit_marker" ]]; then
    printf 'FAIL: direct host invocation accepted an inherited live Wayland socket or executed Quickshell\n' >&2
    exit 1
fi

foreign_guard="$test_root/foreign-private-wayland.guard"
printf '%s\n' "$test_root/private-runtime" >"$foreign_guard"
set +e
run_host env XDG_RUNTIME_DIR="$test_root/private-runtime" \
    WAYLAND_DISPLAY=test-wayland \
    SLEEPY_PRIVATE_WAYLAND_GUARD="$foreign_guard" \
    bash "$test_root/repository/tests/quickshell-core-host.sh" software \
        "$test_root/explicit-bin/qs" >/dev/null 2>&1
foreign_status=$?
set -e
if [[ $foreign_status -eq 0 || -e "$path_marker" || -e "$explicit_marker" ]]; then
    printf 'FAIL: host accepted a private-run guard outside its runtime directory\n' >&2
    exit 1
fi

private_guard="$test_root/private-runtime/.sleepy-private-wayland.guard"
printf '%s\n' "$test_root/private-runtime" >"$private_guard"
chmod 0600 "$private_guard"

set +e
run_host env XDG_RUNTIME_DIR="$test_root/private-runtime" \
    WAYLAND_DISPLAY=test-wayland \
    SLEEPY_PRIVATE_WAYLAND_GUARD="$private_guard" \
    bash "$test_root/repository/tests/quickshell-core-host.sh" software \
        >/dev/null 2>&1
missing_status=$?
set -e
if [[ $missing_status -eq 0 || -e "$path_marker" || -e "$explicit_marker" ]]; then
    printf 'FAIL: host resolved a missing explicit Quickshell binary from PATH\n' >&2
    exit 1
fi

set +e
run_host env XDG_RUNTIME_DIR="$test_root/private-runtime" \
    WAYLAND_DISPLAY=test-wayland \
    SLEEPY_PRIVATE_WAYLAND_GUARD="$private_guard" \
    bash "$test_root/repository/tests/quickshell-core-host.sh" software \
        "$non_executable_qs" >/dev/null 2>&1
non_executable_status=$?
set -e
if [[ $non_executable_status -eq 0 || -e "$path_marker" || -e "$explicit_marker" ]]; then
    printf 'FAIL: host accepted a non-executable Quickshell binary or resolved PATH\n' >&2
    exit 1
fi

run_host env XDG_RUNTIME_DIR="$test_root/private-runtime" \
    WAYLAND_DISPLAY=test-wayland \
    SLEEPY_PRIVATE_WAYLAND_GUARD="$private_guard" \
    bash "$test_root/repository/tests/quickshell-core-host.sh" software \
        "$test_root/explicit-bin/qs"

if [[ -e "$path_marker" ]]; then
    printf 'FAIL: host resolved bare quickshell from PATH instead of the explicit executable\n' >&2
    exit 1
fi
mapfile -t invocation <"$explicit_marker"
if [[ ${#invocation[@]} -ne 4 \
    || "${invocation[0]}" != "$test_root/explicit-bin/qs" \
    || "${invocation[1]}" != "--no-color" \
    || "${invocation[2]}" != "--path" \
    || "${invocation[3]}" != "$test_root/repository/tst_core_desktop_windows.qml" ]]; then
    printf 'FAIL: host did not invoke only the explicit Quickshell executable with fixed argv\n' >&2
    exit 1
fi

printf 'PASS: host gate requires a private guard and invokes only an explicit Quickshell binary\n'
