#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
gate="$repo_root/tests/active-graph.py"

python3 "$gate" "$repo_root/src/shell.qml"

if python3 "$gate" "$repo_root/tests/fixtures/active-graph-forbidden/shell.qml" \
        >"${TMPDIR:-/tmp}/sleepy-active-graph-negative.out" 2>&1; then
    printf 'FAIL: forbidden reachable import fixture passed the active-graph gate\n' >&2
    exit 1
fi

if ! rg -Fq 'Quickshell.Hyprland' \
        "${TMPDIR:-/tmp}/sleepy-active-graph-negative.out"; then
    printf 'FAIL: negative fixture did not report its forbidden reachable import\n' >&2
    exit 1
fi

for payload_style in quoted unquoted; do
    payload_output="${TMPDIR:-/tmp}/sleepy-active-graph-payload-${payload_style}.out"
    if python3 "$gate" \
            "$repo_root/tests/fixtures/active-graph-payload-${payload_style}/src/shell.qml" \
            >"$payload_output" 2>&1; then
        printf 'FAIL: %s hand-written payload fixture passed the active-graph gate\n' \
            "$payload_style" >&2
        exit 1
    fi
    if ! rg -Fq 'hand-written command payload in active surface graph' "$payload_output"; then
        printf 'FAIL: %s payload fixture did not report the payload diagnostic\n' \
            "$payload_style" >&2
        exit 1
    fi
done

printf 'PASS: production active graph is closed and import/quoted/unquoted payload fixtures are rejected\n'
