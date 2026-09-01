#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
shell_executable="${1:-}"
runtime_manifest="${2:-}"
registry="$repo_root/tests/direct-integrations.json"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

[[ -x "$shell_executable" ]] || fail 'packaged full-shell smoke requires the shell executable'
[[ -f "$runtime_manifest" ]] || fail 'packaged full-shell smoke requires runtime-command-paths.json'
jq -e 'type == "object"' "$runtime_manifest" >/dev/null \
  || fail 'runtime command manifest must be an object'

while IFS=$'\t' read -r command optional; do
  resolved="$(jq -er --arg command "$command" '.[$command] // empty' "$runtime_manifest")" || true
  if [[ -z "$resolved" ]]; then
    [[ "$optional" == true ]] || fail "required direct command is not packaged: $command"
    continue
  fi
  [[ "$resolved" == /nix/store/*/bin/"$command" ]] \
    || fail "runtime path is not an exact Nix executable for $command: $resolved"
  [[ -x "$resolved" ]] || fail "registered runtime executable is missing: $resolved"
  rg -Fq "${resolved%/bin/$command}/bin" "$shell_executable" \
    || fail "shell wrapper PATH omits the package that owns $command"
done < <(jq -r '
  .providers[] as $provider
  | $provider.commands[] as $command
  | [$command, (($provider.optionalCommands // []) | index($command) != null)]
  | @tsv
' "$registry")

[[ -n "${WAYLAND_DISPLAY:-}" && -n "${XDG_RUNTIME_DIR:-}" \
    && -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]] \
  || fail 'packaged full-shell smoke requires a private Wayland socket'

smoke_root="$(mktemp -d "${TMPDIR:-/tmp}/sleepy-full-package-smoke.XXXXXX")"
timeout_bin="$(command -v timeout)"
trap 'rm -rf -- "$smoke_root"' EXIT
mkdir -m 700 "$smoke_root/config" "$smoke_root/cache" "$smoke_root/state" "$smoke_root/data"

set +e
env -i \
  HOME="$smoke_root" \
  USER="${USER:-sleepy}" \
  WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
  XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
  XDG_CONFIG_HOME="$smoke_root/config" \
  XDG_CACHE_HOME="$smoke_root/cache" \
  XDG_STATE_HOME="$smoke_root/state" \
  XDG_DATA_HOME="$smoke_root/data" \
  QT_QPA_PLATFORM=wayland \
  QT_QUICK_BACKEND=software \
  "$timeout_bin" --signal=TERM --kill-after=5s 7 "$shell_executable" \
    >"$smoke_root/shell.log" 2>&1
status=$?
set -e
cat "$smoke_root/shell.log"

if rg -q 'Failed to load configuration|is not a type|ReferenceError:|TypeError:|SyntaxError:|module ".*" is not installed|QQmlApplicationEngine failed' \
    "$smoke_root/shell.log"; then
  fail 'installed full shell did not resolve its complete QML/plugin graph'
fi
[[ $status -eq 124 ]] || fail "installed full shell exited unexpectedly with status $status"

printf 'PASS: packaged full shell resolves from an empty XDG home with exact runtime paths\n'
