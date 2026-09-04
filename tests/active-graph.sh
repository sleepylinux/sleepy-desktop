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

if ! rg -Fq 'forbidden runtime identity' \
        "${TMPDIR:-/tmp}/sleepy-active-graph-negative.out"; then
    printf 'FAIL: negative fixture did not report its forbidden runtime identity\n' >&2
    exit 1
fi

for payload_style in quoted unquoted; do
    payload_output="${TMPDIR:-/tmp}/sleepy-active-graph-payload-${payload_style}.out"
    if python3 "$gate" \
            "$repo_root/tests/fixtures/active-graph-payload-${payload_style}/src/shell.qml" \
            >"$payload_output" 2>&1; then
        printf 'FAIL: %s unsafe argv fixture passed the active-graph gate\n' \
            "$payload_style" >&2
        exit 1
    fi
    if ! rg -q -e 'shell interpreter command is forbidden|credential-bearing argv is forbidden' "$payload_output"; then
        printf 'FAIL: %s unsafe argv fixture did not report the safety diagnostic\n' \
            "$payload_style" >&2
        exit 1
    fi
done

if python3 "$gate" \
        "$repo_root/tests/fixtures/active-graph-dropped-root/src/shell.qml" \
        >"${TMPDIR:-/tmp}/sleepy-active-graph-dropped-root.out" 2>&1; then
    printf 'FAIL: directly instantiated root declared dropped passed the gate\n' >&2
    exit 1
fi
if ! rg -Fq 'directly instantiated production root is missing or declared dropped' \
        "${TMPDIR:-/tmp}/sleepy-active-graph-dropped-root.out"; then
    printf 'FAIL: dropped root fixture did not report the manifest contradiction\n' >&2
    exit 1
fi

printf 'PASS: directly instantiated roots cannot be declared dropped\n'
printf 'PASS: production active graph is closed and import/quoted/unquoted payload fixtures are rejected\n'
