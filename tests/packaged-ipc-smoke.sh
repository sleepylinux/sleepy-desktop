#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

[[ $# -eq 3 ]] || fail 'usage: packaged-ipc-smoke.sh WRAPPER PINNED_QS CONFIG_PATH'
wrapper="$1"
pinned_qs="$2"
config_path="$3"
[[ -x "$wrapper" ]] || fail 'packaged sleepy-shell-ipc is not executable'
[[ -x "$pinned_qs" ]] || fail 'pinned Quickshell IPC client is not executable'
[[ -f "$config_path" ]] || fail 'packaged shell.qml is missing'
command -v strace >/dev/null 2>&1 || fail 'strace is required'

runtime="$TMPDIR/sleepy-ipc-empty-runtime"
private_home="$TMPDIR/sleepy-ipc-home"
trace="$TMPDIR/sleepy-ipc-execve.trace"
log="$TMPDIR/sleepy-ipc.log"
mkdir -m 700 "$runtime" "$private_home"

set +e
env -u WAYLAND_DISPLAY -u WAYLAND_SOCKET -u HYPRLAND_INSTANCE_SIGNATURE \
  -u SWAYSOCK -u I3SOCK \
  XDG_RUNTIME_DIR="$runtime" HOME="$private_home" \
  strace -f -qq -s 4096 -e trace=execve -o "$trace" \
    "$wrapper" call sleepy toggleLauncher >"$log" 2>&1
status=$?
set -e

[[ $status -ne 0 ]] \
  || fail 'IPC unexpectedly found a shell instance in the private empty runtime'
expected="execve(\"$pinned_qs\", [\"$pinned_qs\", \"ipc\", \"--path\", \"$config_path\", \"call\", \"sleepy\", \"toggleLauncher\"]"
rg -Fq "$expected" "$trace" \
  || {
    cat "$trace" >&2
    fail 'generated wrapper did not exec pinned qs with exact IPC argv order'
  }

printf 'PASS: packaged IPC wrapper used pinned qs and exact argv in an empty runtime\n'
