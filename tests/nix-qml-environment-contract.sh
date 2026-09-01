#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/sleepy-nix-qml-env.XXXXXX")"
cleanup() {
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

def stop(_signum, _frame):
    raise SystemExit(0)

signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)
signal.pause()
PY
chmod 0700 "$fake_compositor"

aggregate_probe="$test_root/aggregate-probe"
cat >"$aggregate_probe" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${DISPLAY:-}" != "$SLEEPY_EXPECTED_XVFB_DISPLAY" ]]; then
    printf 'aggregate probe expected DISPLAY=%s, observed %s\n' \
        "$SLEEPY_EXPECTED_XVFB_DISPLAY" "${DISPLAY:-(unset)}" >&2
    exit 42
fi
: >"$SLEEPY_AGGREGATE_PROBE_MARKER"
SH
chmod 0700 "$aggregate_probe"

qml_check_block="$(
    sed -n '/^          qml = pkgs.runCommand /,/^          package = pkgs.runCommand /p' \
        "$repo_root/flake.nix"
)"
wrapped='bash tests/with-private-wayland.sh bash tests/run.sh'
direct='bash tests/run.sh'
marker="$test_root/aggregate-ran"
expected_display=:sleepy-xvfb-contract

set +e
if rg -Fq "$wrapped" <<<"$qml_check_block"; then
    DISPLAY="$expected_display" \
    SLEEPY_EXPECTED_XVFB_DISPLAY="$expected_display" \
    SLEEPY_AGGREGATE_PROBE_MARKER="$marker" \
    SLEEPY_TEST_WAYLAND_COMPOSITOR="$fake_compositor" \
    SLEEPY_PRIVATE_WAYLAND_TIMEOUT_SECONDS=10 \
        bash "$repo_root/tests/with-private-wayland.sh" "$aggregate_probe" \
        >/dev/null 2>&1
    status=$?
elif rg -Fxq "            $direct" <<<"$qml_check_block"; then
    DISPLAY="$expected_display" \
    SLEEPY_EXPECTED_XVFB_DISPLAY="$expected_display" \
    SLEEPY_AGGREGATE_PROBE_MARKER="$marker" \
        "$aggregate_probe" >/dev/null 2>&1
    status=$?
else
    printf 'FAIL: Nix qml check has an unrecognized aggregate test invocation\n' >&2
    exit 1
fi
set -e

if [[ $status -ne 0 || ! -e "$marker" ]]; then
    printf 'FAIL: declared Nix aggregate invocation removed the Xvfb DISPLAY required by RHI tests\n' >&2
    exit 1
fi

printf 'PASS: Nix aggregate preserves Xvfb while real host gates remain privately wrapped\n'
