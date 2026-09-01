#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
flake="$repo_root/flake.nix"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

rg -Fq 'withIpcClient ? false' "$flake" \
  || fail 'desktop package helper must make the IPC companion explicit'
rg -Fq 'makeWrapper "${quickshellWithModules}/bin/qs" "$out/bin/sleepy-shell-ipc"' "$flake" \
  || fail 'IPC companion must execute the same pinned Quickshell build as sleepy-shell'
rg -Fq -- '--add-flags "ipc --path $out/${installRoot}/shell.qml"' "$flake" \
  || fail 'IPC companion must select the exact packaged shell path'
rg -Fq 'withIpcClient = true;' "$flake" \
  || fail 'sleepy-shell package must install its version-matched IPC companion'
rg -Fq 'test -x "$shell_package/bin/sleepy-shell-ipc"' "$flake" \
  || fail 'package check must require the IPC companion'
rg -Fq 'tests/packaged-ipc-smoke.sh' "$flake" \
  || fail 'Nix package check must execute the generated IPC wrapper smoke test'
rg -Fq 'pkgs.strace' "$flake" \
  || fail 'generated IPC wrapper smoke must observe the real execve boundary'

printf 'PASS: sleepy-shell ships a pinned version-matched IPC client\n'
