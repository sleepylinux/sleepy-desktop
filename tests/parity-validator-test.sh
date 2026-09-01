#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=tests/lib/parity-validator.sh
source "$repo_root/tests/lib/parity-validator.sh"

fixture_root="$(mktemp -d)"
trap 'rm -rf -- "$fixture_root"' EXIT
mkdir -p "$fixture_root/tests/qml"
printf 'selector_alpha\n' >"$fixture_root/tests/alpha.sh"
printf 'function selector_beta() {}\n' >"$fixture_root/tests/qml/beta.qml"
printf '%s\n' 'src/modules/A.qml' 'src/services/B.qml' >"$fixture_root/inventory.txt"
printf '%s\n' 'case-a' 'case-b' >"$fixture_root/cases.txt"

base="$fixture_root/base.json"
cat >"$base" <<'JSON'
{
  "formatVersion": 1,
  "upstreamRevision": "24aa15eefdb146350d2548c0a015b04eddbd1008",
  "referenceComparison": {
    "id": "upstream-v2.4.0-vs-sleepy-reference-pixels",
    "upstreamRevision": "24aa15eefdb146350d2548c0a015b04eddbd1008",
    "comparison": "exact-pixel-and-layout",
    "environment": "private-wayland-vm",
    "status": "deferred-environment",
    "reason": "Exact capture requires private Wayland in the reference VM",
    "requiredArtifacts": ["upstream-v2.4.0.png", "sleepy-task10.png", "pixel-layout-comparison.json"]
  },
  "entries": [
    {"path":"src/modules/A.qml","disposition":"render","sleepyOwner":"sleepy-desktop","protocol":"desktop-v3","degradedState":"hidden","tests":["tests/alpha.sh#selector_alpha"]},
    {"path":"src/services/B.qml","disposition":"rewrite","sleepyOwner":"sleepy-session","protocol":"desktop-v3","degradedState":"unavailable","tests":["tests/qml/beta.qml#selector_beta"]}
  ],
  "objectiveCases": [
    {"id":"case-a","area":"A","status":"verified","tests":["tests/alpha.sh#selector_alpha"]},
    {"id":"case-b","area":"B","status":"deferred-environment","reason":"requires private Wayland","tests":["tests/qml/beta.qml#selector_beta"]}
  ]
}
JSON

validate() {
  validate_parity_manifest "$1" "$fixture_root/inventory.txt" \
    "$fixture_root/cases.txt" "$fixture_root"
}

expect_rejected() {
  local label="$1"
  local candidate="$2"
  if validate "$candidate" >/dev/null 2>&1; then
    printf 'FAIL: parity validator accepted %s\n' "$label" >&2
    exit 1
  fi
}

validate "$base"

jq 'del(.entries[0])' "$base" >"$fixture_root/missing-entry.json"
expect_rejected 'missing inventory entry' "$fixture_root/missing-entry.json"

jq '.entries += [.entries[0]]' "$base" >"$fixture_root/duplicate-entry.json"
expect_rejected 'duplicate inventory entry' "$fixture_root/duplicate-entry.json"

jq '.entries[0].sleepyOwner = "shell"' "$base" >"$fixture_root/invalid-owner.json"
expect_rejected 'invalid owner' "$fixture_root/invalid-owner.json"

jq '.entries[0].disposition = "later"' "$base" >"$fixture_root/invalid-disposition.json"
expect_rejected 'invalid disposition' "$fixture_root/invalid-disposition.json"

jq '.entries[0].tests = ["tests/does-not-exist.sh"]' "$base" >"$fixture_root/fake-test.json"
expect_rejected 'nonexistent test file' "$fixture_root/fake-test.json"

jq '.entries[0].tests = ["tests/alpha.sh#not_present"]' "$base" >"$fixture_root/fake-selector.json"
expect_rejected 'nonexistent test selector' "$fixture_root/fake-selector.json"

jq 'del(.objectiveCases[0])' "$base" >"$fixture_root/missing-case.json"
expect_rejected 'missing required objective' "$fixture_root/missing-case.json"

jq 'del(.objectiveCases[1].reason)' "$base" >"$fixture_root/unjustified-deferral.json"
expect_rejected 'unjustified environment deferral' "$fixture_root/unjustified-deferral.json"

jq 'del(.referenceComparison)' "$base" >"$fixture_root/missing-reference-comparison.json"
expect_rejected 'missing exact reference comparison' \
  "$fixture_root/missing-reference-comparison.json"

jq '.referenceComparison.status = "verified"' "$base" \
  >"$fixture_root/false-reference-verification.json"
expect_rejected 'false exact reference verification' \
  "$fixture_root/false-reference-verification.json"

printf 'PASS: parity validator rejects false coverage evidence\n'
