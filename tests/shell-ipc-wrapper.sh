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
rg -Fq -- '--add-flags "ipc --config sleepy"' "$flake" \
  || fail 'IPC companion must select the closed sleepy handler configuration'
rg -Fq 'withIpcClient = true;' "$flake" \
  || fail 'sleepy-shell package must install its version-matched IPC companion'
rg -Fq 'test -x "$shell_package/bin/sleepy-shell-ipc"' "$flake" \
  || fail 'package check must require the IPC companion'

printf 'PASS: sleepy-shell ships a pinned version-matched IPC client\n'
