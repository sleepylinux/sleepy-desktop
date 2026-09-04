#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=tests/lib/parity-validator.sh
source "$repo_root/tests/lib/parity-validator.sh"

fixture_root="$(mktemp -d)"
trap 'rm -rf -- "$fixture_root"' EXIT
mkdir -p "$fixture_root/tests/qml"

cat >"$fixture_root/tests/alpha.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'PASS: alpha evidence\n'
SH
chmod +x "$fixture_root/tests/alpha.sh"
cat >"$fixture_root/tests/qml/tst_beta.qml" <<'QML'
import QtQuick 6.0
import QtTest 1.0
TestCase {
    name: "Beta"
    function test_beta() {}
}
QML

printf '%s\n' 'src/modules/A.qml' 'src/services/B.qml' >"$fixture_root/candidate.txt"
printf '%s\n' 'case-a' 'case-b' >"$fixture_root/cases.txt"
inventory_hash='dbaa12050088369e6a3b5bba271d87aedc3cc0ec1b4f38d64448054d199e89a9'
cat >"$fixture_root/upstream.json" <<JSON
{
  "formatVersion": 1,
  "provenance": {
    "repository": "https://github.com/caelestia-dots/shell",
    "tag": "v2.4.0",
    "revision": "24aa15eefdb146350d2548c0a015b04eddbd1008",
    "verifiedImportCommit": "d5e10fb9b765afbd6c56c2b359875e8a66584ff3",
    "derivation": "fixture normalized paths",
    "addedPathCount": 2,
    "overwrittenPathCount": 0,
    "overwrittenPaths": [],
    "pathsSha256": "$inventory_hash",
    "pathCount": 2
  },
  "paths": ["src/modules/A.qml", "src/services/B.qml"]
}
JSON
cat >"$fixture_root/registry.json" <<'JSON'
{
  "formatVersion": 1,
  "qmlRunners": [{
    "id": "qml-software-suite",
    "kind": "qmltestrunner-directory",
    "input": "tests/qml",
    "filePattern": "tst_*.qml"
  }],
  "shellRunners": [{
    "id": "shell-alpha",
    "path": "tests/alpha.sh",
    "passIdentity": "PASS: alpha evidence"
  }]
}
JSON

base="$fixture_root/base.json"
cat >"$base" <<'JSON'
{
  "formatVersion": 2,
  "upstreamRevision": "24aa15eefdb146350d2548c0a015b04eddbd1008",
  "referenceComparison": {
    "id": "upstream-v2.4.0-vs-sleepy-reference-pixels",
    "upstreamRevision": "24aa15eefdb146350d2548c0a015b04eddbd1008",
    "comparison": "exact-pixel-and-layout",
    "environment": "private-wayland-vm",
    "status": "verified",
    "requiredArtifacts": ["upstream-v2.4.0.png", "sleepy-task10.png", "pixel-layout-comparison.json"]
  },
  "entries": [
    {
      "path":"src/modules/A.qml",
      "disposition":"render",
      "sleepyOwner":"sleepy-desktop",
      "runtimeReachable":true,
      "protocol":"desktop-v3",
      "degradedState":"hidden",
      "behaviorStatus":"verified",
      "tests":["tests/alpha.sh#PASS: alpha evidence"]
    },
    {
      "path":"src/services/B.qml",
      "disposition":"rewrite",
      "sleepyOwner":"sleepy-session",
      "runtimeReachable":true,
      "protocol":"desktop-v3",
      "degradedState":"unavailable",
      "behaviorStatus":"verified",
      "tests":["tests/qml/tst_beta.qml#test_beta"]
    }
  ],
  "objectiveCases": [
    {
      "id":"case-a",
      "area":"A",
      "status":"verified",
      "tests":["tests/alpha.sh#PASS: alpha evidence"]
    },
    {
      "id":"case-b",
      "area":"B",
      "status":"verified",
      "tests":["tests/qml/tst_beta.qml#test_beta"]
    }
  ]
}
JSON

validate_with() {
  local candidate="$1"
  local inventory="${2:-$fixture_root/candidate.txt}"
  local upstream="${3:-$fixture_root/upstream.json}"
  local registry="${4:-$fixture_root/registry.json}"
  validate_parity_manifest "$candidate" "$upstream" "$inventory" \
    "$fixture_root/cases.txt" "$fixture_root" "$registry" "$inventory_hash" 2 \
    2 0 '[]' 'fixture normalized paths'
}

expect_rejected() {
  local label="$1"
  local candidate="$2"
  local inventory="${3:-$fixture_root/candidate.txt}"
  local upstream="${4:-$fixture_root/upstream.json}"
  local registry="${5:-$fixture_root/registry.json}"
  if validate_with "$candidate" "$inventory" "$upstream" "$registry" >/dev/null 2>&1; then
    printf 'FAIL: parity validator accepted %s\n' "$label" >&2
    exit 1
  fi
}

validate_with "$base"

jq '.entries[0].behaviorStatus = "excluded-non-runtime" | .entries[0].disposition = "build-only" | .entries[0].sleepyOwner = "none" | .entries[0].runtimeReachable = false | .entries[0].exclusionReason = "fixture compiler helper"' "$base" \
  >"$fixture_root/valid-non-runtime-exclusion.json"
validate_with "$fixture_root/valid-non-runtime-exclusion.json"

jq 'del(.entries[0])' "$base" >"$fixture_root/missing-entry.json"
expect_rejected 'missing inventory entry' "$fixture_root/missing-entry.json"

jq '.entries += [.entries[0]]' "$base" >"$fixture_root/duplicate-entry.json"
expect_rejected 'duplicate inventory entry' "$fixture_root/duplicate-entry.json"

jq '.entries[0].sleepyOwner = "shell"' "$base" >"$fixture_root/invalid-owner.json"
expect_rejected 'invalid owner' "$fixture_root/invalid-owner.json"

jq '.entries[0].disposition = "later"' "$base" >"$fixture_root/invalid-disposition.json"
expect_rejected 'invalid disposition' "$fixture_root/invalid-disposition.json"

jq 'del(.entries[0].behaviorStatus)' "$base" >"$fixture_root/missing-behavior-status.json"
expect_rejected 'missing behavior status' "$fixture_root/missing-behavior-status.json"

jq '.entries[0].behaviorStatus = "mostly"' "$base" >"$fixture_root/invalid-behavior-status.json"
expect_rejected 'invalid behavior status' "$fixture_root/invalid-behavior-status.json"

jq '.entries[0].behaviorStatus = "approved-deviation"' "$base" \
  >"$fixture_root/unjustified-approved-deviation.json"
expect_rejected 'unjustified approved deviation' \
  "$fixture_root/unjustified-approved-deviation.json"

jq '.entries[0].behaviorStatus = "deferred-environment" | .entries[0].environmentReason = "private Wayland VM"' "$base" \
  >"$fixture_root/deferred-reachable-entry.json"
expect_rejected 'deferred reachable entry' \
  "$fixture_root/deferred-reachable-entry.json"

jq '.entries[0].behaviorStatus = "excluded-non-runtime" | .entries[0].disposition = "unreachable" | .entries[0].sleepyOwner = "none" | .entries[0].exclusionReason = "fixture path is reachable QML"' "$base" \
  >"$fixture_root/excluded-reachable-qml.json"
expect_rejected 'excluded reachable QML entry' \
  "$fixture_root/excluded-reachable-qml.json"

jq '.entries[0].behaviorStatus = "excluded-non-runtime" | .entries[0].disposition = "replaced-asset" | .entries[0].sleepyOwner = "none" | .entries[0].runtimeReachable = false | .entries[0].exclusionReason = "fixture asset is replaced"' "$base" \
  >"$fixture_root/replacement-without-path.json"
expect_rejected 'replacement asset without replacementPath' \
  "$fixture_root/replacement-without-path.json"

jq '.entries[0].tests = ["tests/does-not-exist.sh#PASS: fake"]' "$base" \
  >"$fixture_root/fake-test.json"
expect_rejected 'nonexistent test file' "$fixture_root/fake-test.json"

jq '.entries[1].tests = ["tests/qml/tst_beta.qml#test_not_present"]' "$base" \
  >"$fixture_root/fake-selector.json"
expect_rejected 'nonexistent test selector' "$fixture_root/fake-selector.json"

cat >"$fixture_root/tests/qml/tst_comment.qml" <<'QML'
// function test_comment_only() {}
QML
jq '.entries[1].tests = ["tests/qml/tst_comment.qml#test_comment_only"]' "$base" \
  >"$fixture_root/comment-only-selector.json"
expect_rejected 'comment-only selector' "$fixture_root/comment-only-selector.json"

printf 'function test_dead_selector() {}\n' >"$fixture_root/tests/qml/dead.qml"
jq '.entries[1].tests = ["tests/qml/dead.qml#test_dead_selector"]' "$base" \
  >"$fixture_root/dead-selector.json"
expect_rejected 'dead uninvoked QML selector' "$fixture_root/dead-selector.json"

cat >"$fixture_root/tests/uninvoked.sh" <<'SH'
#!/usr/bin/env bash
printf 'PASS: uninvoked evidence\n'
SH
chmod +x "$fixture_root/tests/uninvoked.sh"
jq '.entries[0].tests = ["tests/uninvoked.sh#PASS: uninvoked evidence"]' "$base" \
  >"$fixture_root/uninvoked-shell.json"
expect_rejected 'uninvoked shell evidence' "$fixture_root/uninvoked-shell.json"

jq 'del(.entries[0])' "$base" >"$fixture_root/deleted-source-and-entry.json"
printf '%s\n' 'src/services/B.qml' >"$fixture_root/deleted-source-inventory.txt"
expect_rejected 'deletion from candidate tree and manifest' \
  "$fixture_root/deleted-source-and-entry.json" \
  "$fixture_root/deleted-source-inventory.txt"

jq '.paths = ["src/services/B.qml"] | .provenance.pathCount = 1' \
  "$fixture_root/upstream.json" >"$fixture_root/tampered-upstream.json"
expect_rejected 'tampered immutable upstream inventory' "$base" \
  "$fixture_root/candidate.txt" "$fixture_root/tampered-upstream.json"

jq 'del(.objectiveCases[0])' "$base" >"$fixture_root/missing-case.json"
expect_rejected 'missing required objective' "$fixture_root/missing-case.json"

jq '.objectiveCases[1].status = "deferred-environment" | .objectiveCases[1].reason = "private Wayland VM"' "$base" \
  >"$fixture_root/deferred-objective.json"
expect_rejected 'deferred objective case' "$fixture_root/deferred-objective.json"

jq 'del(.referenceComparison)' "$base" >"$fixture_root/missing-reference-comparison.json"
expect_rejected 'missing exact reference comparison' \
  "$fixture_root/missing-reference-comparison.json"

jq '.referenceComparison.status = "deferred-environment" | .referenceComparison.reason = "private Wayland VM"' "$base" \
  >"$fixture_root/deferred-reference-verification.json"
expect_rejected 'deferred exact reference verification' \
  "$fixture_root/deferred-reference-verification.json"

jq '.shellRunners = []' "$fixture_root/registry.json" >"$fixture_root/uninvoked-registry.json"
expect_rejected 'registry with no mandatory shell runner' "$base" \
  "$fixture_root/candidate.txt" "$fixture_root/upstream.json" \
  "$fixture_root/uninvoked-registry.json"

results="$fixture_root/results.txt"
: >"$results"
run_parity_shell_evidence "$fixture_root/registry.json" "$fixture_root" "$results" >/dev/null
printf 'PASS   : Beta::test_beta()\n' >"$fixture_root/qml.log"
record_parity_qml_evidence "$base" "$fixture_root/qml.log" "$results"
validate_parity_evidence_results "$base" "$results" >/dev/null
printf 'tests/alpha.sh#PASS: alpha evidence\n' >"$fixture_root/incomplete-results.txt"
if validate_parity_evidence_results "$base" "$fixture_root/incomplete-results.txt" \
    >/dev/null 2>&1; then
  printf 'FAIL: evidence result contract accepted missing QML execution\n' >&2
  exit 1
fi

printf 'PASS: parity validator rejects mutable inventory and false executable evidence\n'
