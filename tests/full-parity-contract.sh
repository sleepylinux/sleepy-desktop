#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
manifest="$repo_root/tests/parity-manifest.json"

jq -e '.formatVersion == 2' "$manifest" >/dev/null

jq -e '
  [.entries[]
    | select(
        .behaviorStatus != "verified" and
        .behaviorStatus != "excluded-non-runtime"
      )]
  | length == 0
' "$manifest" >/dev/null

jq -e '
  [.objectiveCases[] | select(.status != "verified")]
  | length == 0
' "$manifest" >/dev/null

jq -e '.referenceComparison.status == "verified"' "$manifest" >/dev/null

if rg -n 'approved-deviation|deferred-environment|drop-with-reason' "$manifest"; then
  printf 'FAIL: parity manifest still permits an incomplete reachable outcome\n' >&2
  exit 1
fi

printf 'PASS: every reachable upstream v2.4.0 parity outcome is verified\n'
