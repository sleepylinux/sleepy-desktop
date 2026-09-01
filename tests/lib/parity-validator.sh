#!/usr/bin/env bash

parity_validation_error() {
  printf 'FAIL: %s\n' "$*" >&2
  return 1
}

parity_reference_parts() {
  local reference="$1"
  PARITY_REFERENCE_PATH="${reference%%#*}"
  PARITY_REFERENCE_SELECTOR=""
  if [[ "$reference" == *'#'* ]]; then
    PARITY_REFERENCE_SELECTOR="${reference#*#}"
  fi
}

parity_reference_exists() {
  local reference="$1"
  local repo_root="$2"
  local evidence_registry="$3"
  local resolved

  parity_reference_parts "$reference"
  [[ -n "$PARITY_REFERENCE_PATH" && "$PARITY_REFERENCE_PATH" == tests/*
      && "$PARITY_REFERENCE_PATH" != *'/../'* && "$PARITY_REFERENCE_PATH" != ../*
      && "$PARITY_REFERENCE_PATH" != */.. && "$PARITY_REFERENCE_PATH" != *//* ]] \
    || parity_validation_error "invalid test reference: $reference" || return 1
  [[ -n "$PARITY_REFERENCE_SELECTOR" ]] \
    || parity_validation_error "empty test selector: $reference" || return 1
  resolved="$repo_root/$PARITY_REFERENCE_PATH"
  [[ -f "$resolved" ]] \
    || parity_validation_error "test reference does not exist: $reference" || return 1

  if [[ "$PARITY_REFERENCE_PATH" == tests/qml/* ]]; then
    [[ "$PARITY_REFERENCE_PATH" == tests/qml/tst_*.qml
        && "$PARITY_REFERENCE_SELECTOR" =~ ^test_[A-Za-z0-9_]+$ ]] \
      || parity_validation_error "QML evidence is not a runnable tst_ test: $reference" \
      || return 1
    jq -e --arg path "$PARITY_REFERENCE_PATH" '
      any(.qmlRunners[];
        .id == "qml-software-suite" and
        .kind == "qmltestrunner-directory" and
        .input == "tests/qml" and
        .filePattern == "tst_*.qml" and
        (.input as $input | $path | startswith($input + "/")))
    ' "$evidence_registry" >/dev/null \
      || parity_validation_error "QML evidence has no mandatory runner: $reference" \
      || return 1
    rg -q "^[[:space:]]*function[[:space:]]+$PARITY_REFERENCE_SELECTOR[[:space:]]*\\(" \
      "$resolved" \
      || parity_validation_error "QML selector is not an actual test function: $reference" \
      || return 1
    return 0
  fi

  [[ "$PARITY_REFERENCE_PATH" == tests/*.sh
      && "$PARITY_REFERENCE_SELECTOR" == 'PASS: '* ]] \
    || parity_validation_error "shell evidence must use an anchored PASS identity: $reference" \
    || return 1
  jq -e --arg path "$PARITY_REFERENCE_PATH" \
      --arg pass "$PARITY_REFERENCE_SELECTOR" '
    any(.shellRunners[]; .path == $path and .passIdentity == $pass)
  ' "$evidence_registry" >/dev/null \
    || parity_validation_error "shell evidence has no mandatory runner: $reference" \
    || return 1
}

validate_parity_manifest() {
  local manifest="$1"
  local upstream_inventory="$2"
  local candidate_inventory="$3"
  local required_cases_file="$4"
  local repo_root="$5"
  local evidence_registry="$6"
  local expected_inventory_hash="$7"
  local expected_inventory_count="$8"
  local expected_added_count="$9"
  local expected_overwritten_count="${10}"
  local expected_overwritten_paths="${11}"
  local expected_derivation="${12}"
  local scratch reference actual_inventory_hash

  command -v jq >/dev/null 2>&1 \
    || parity_validation_error 'jq is required' || return 1
  command -v sha256sum >/dev/null 2>&1 \
    || parity_validation_error 'sha256sum is required' || return 1
  [[ -f "$manifest" ]] \
    || parity_validation_error 'tests/parity-manifest.json is missing' || return 1
  [[ -f "$upstream_inventory" && -f "$candidate_inventory"
      && -f "$required_cases_file" && -f "$evidence_registry" ]] \
    || parity_validation_error 'validator inputs are missing' || return 1

  [[ "$expected_inventory_hash" =~ ^[0-9a-f]{64}$
      && "$expected_inventory_count" =~ ^[1-9][0-9]*$
      && "$expected_added_count" =~ ^[0-9]+$
      && "$expected_overwritten_count" =~ ^[0-9]+$ ]] \
    || parity_validation_error 'expected immutable inventory identity is invalid' || return 1
  jq -e --arg hash "$expected_inventory_hash" \
      --argjson count "$expected_inventory_count" \
      --argjson added "$expected_added_count" \
      --argjson overwritten "$expected_overwritten_count" \
      --argjson overwrittenPaths "$expected_overwritten_paths" \
      --arg derivation "$expected_derivation" '
    .formatVersion == 1 and
    .provenance.repository == "https://github.com/caelestia-dots/shell" and
    .provenance.tag == "v2.4.0" and
    .provenance.revision == "24aa15eefdb146350d2548c0a015b04eddbd1008" and
    .provenance.verifiedImportCommit ==
      "d5e10fb9b765afbd6c56c2b359875e8a66584ff3" and
    .provenance.derivation == $derivation and
    .provenance.addedPathCount == $added and
    .provenance.overwrittenPathCount == $overwritten and
    .provenance.overwrittenPaths == $overwrittenPaths and
    (.provenance.addedPathCount + .provenance.overwrittenPathCount) == $count and
    .provenance.pathsSha256 == $hash and
    .provenance.pathCount == $count and
    (.paths | type == "array") and
    (.paths | length) == .provenance.pathCount and
    ([.paths[]] | length) == ([.paths[]] | unique | length) and
    all(.paths[]; type == "string" and
      test("^src/(modules|services|plugin)/") and
      test("\\.(qml|cpp|hpp|h)$"))
  ' "$upstream_inventory" >/dev/null \
    || parity_validation_error 'immutable upstream v2.4.0 inventory provenance is invalid' \
    || return 1
  actual_inventory_hash="$(jq -r '.paths[]' "$upstream_inventory" \
    | LC_ALL=C sort | sha256sum | awk '{print $1}')"
  [[ "$actual_inventory_hash" == "$expected_inventory_hash" ]] \
    || parity_validation_error 'immutable upstream v2.4.0 inventory hash changed' \
    || return 1

  jq -e '
    .formatVersion == 1 and
    (.qmlRunners == [{
      "id":"qml-software-suite",
      "kind":"qmltestrunner-directory",
      "input":"tests/qml",
      "filePattern":"tst_*.qml"
    }]) and
    (.shellRunners | type == "array" and length > 0) and
    ([.shellRunners[].id] | length) == ([.shellRunners[].id] | unique | length) and
    ([.shellRunners[].path] | length) == ([.shellRunners[].path] | unique | length) and
    all(.shellRunners[];
      (.id | type == "string" and length > 0) and
      (.path | type == "string" and test("^tests/[A-Za-z0-9._-]+\\.sh$")) and
      (.passIdentity | type == "string" and startswith("PASS: ")))
  ' "$evidence_registry" >/dev/null \
    || parity_validation_error 'parity evidence registry is invalid' || return 1

  jq -e '
    (.formatVersion == 1 or .formatVersion == 2) and
    .upstreamRevision == "24aa15eefdb146350d2548c0a015b04eddbd1008" and
    (.entries | type == "array" and length > 0) and
    (.objectiveCases | type == "array" and length > 0) and
    (.referenceComparison | type == "object")
  ' "$manifest" >/dev/null \
    || parity_validation_error 'parity manifest top-level contract is invalid' || return 1

  jq -e '
    if .formatVersion == 2 then
      .referenceComparison.id == "upstream-v2.4.0-vs-sleepy-reference-pixels" and
      .referenceComparison.upstreamRevision == .upstreamRevision and
      .referenceComparison.comparison == "exact-pixel-and-layout" and
      .referenceComparison.environment == "private-wayland-vm" and
      .referenceComparison.status == "verified" and
      (.referenceComparison | has("reason") | not) and
      (.referenceComparison.requiredArtifacts == [
        "upstream-v2.4.0.png", "sleepy-task10.png", "pixel-layout-comparison.json"
      ])
    else
    .referenceComparison.id == "upstream-v2.4.0-vs-sleepy-reference-pixels" and
    .referenceComparison.upstreamRevision == .upstreamRevision and
    .referenceComparison.comparison == "exact-pixel-and-layout" and
    .referenceComparison.environment == "private-wayland-vm" and
    .referenceComparison.status == "deferred-environment" and
    (.referenceComparison.reason | type == "string" and length > 0
      and test("private Wayland") and test("VM")) and
    (.referenceComparison.requiredArtifacts == [
      "upstream-v2.4.0.png", "sleepy-task10.png", "pixel-layout-comparison.json"
    ])
    end
  ' "$manifest" >/dev/null || {
    parity_validation_error \
      'exact upstream reference comparison status is inconsistent with the manifest version'
    return 1
  }

  scratch="$(mktemp -d)" || return 1
  jq -r '.entries[].path' "$manifest" | LC_ALL=C sort >"$scratch/declared-paths"
  LC_ALL=C sort "$candidate_inventory" >"$scratch/candidate-paths"
  jq -r '.paths[]' "$upstream_inventory" | LC_ALL=C sort >"$scratch/upstream-paths"
  if ! diff -u "$scratch/candidate-paths" "$scratch/declared-paths"; then
    rm -rf -- "$scratch"
    parity_validation_error \
      'manifest must contain every current candidate QML/C++ module or service exactly once'
    return 1
  fi
  if comm -23 "$scratch/upstream-paths" "$scratch/declared-paths" \
      >"$scratch/missing-upstream" && [[ -s "$scratch/missing-upstream" ]]; then
    while IFS= read -r reference; do
      printf '%s\n' "$reference" >&2
    done <"$scratch/missing-upstream"
    rm -rf -- "$scratch"
    parity_validation_error \
      'manifest and candidate must retain every immutable upstream v2.4.0 inventory path'
    return 1
  fi

  jq -e '
    .formatVersion as $formatVersion |
    ([.entries[].path] | length) == ([.entries[].path] | unique | length) and
    all(.entries[];
      (.path | type == "string" and length > 0) and
      (if $formatVersion == 2
       then (.runtimeReachable | type == "boolean") and
         (if .behaviorStatus == "verified"
          then .runtimeReachable == true and
            (.disposition | IN("render", "move", "rewrite")) and
            (.sleepyOwner | IN("sleepy-desktop", "sleepy-session")) and
            (has("exclusionReason") | not) and
            (has("replacementPath") | not)
          elif .behaviorStatus == "excluded-non-runtime"
          then .runtimeReachable == false and
            (.disposition | IN("build-only", "license", "unreachable", "replaced-asset")) and
            .sleepyOwner == "none" and
            (.exclusionReason | type == "string" and length > 0) and
            (if .disposition == "replaced-asset"
             then (.replacementPath | type == "string" and length > 0)
             else (has("replacementPath") | not)
             end)
          else false
          end)
       else
         (.disposition | IN("render", "move", "rewrite", "drop-with-reason")) and
         (.sleepyOwner | IN("sleepy-desktop", "sleepy-session", "none")) and
         (.behaviorStatus | IN("verified", "approved-deviation", "deferred-environment")) and
         (if .behaviorStatus == "approved-deviation" or .disposition == "drop-with-reason"
          then (.approvedDeviation | type == "string" and length > 0)
          else has("approvedDeviation") | not
          end) and
         (if .behaviorStatus == "deferred-environment"
          then (.environmentReason | type == "string" and length > 0
            and (test("private Wayland") or test("VM")))
          else has("environmentReason") | not
          end)
       end) and
      (.protocol | type == "string" and length > 0) and
      (.degradedState | type == "string" and length > 0) and
      (.tests | type == "array" and length > 0 and
        all(.[]; type == "string" and length > 0))
    )
  ' "$manifest" >/dev/null || {
    rm -rf -- "$scratch"
    parity_validation_error 'an inventory entry is incomplete or has a dishonest behavior status'
    return 1
  }

  jq -r '.objectiveCases[].id' "$manifest" | LC_ALL=C sort >"$scratch/declared-cases"
  LC_ALL=C sort "$required_cases_file" >"$scratch/required-cases"
  if ! diff -u "$scratch/required-cases" "$scratch/declared-cases"; then
    rm -rf -- "$scratch"
    parity_validation_error 'objective case matrix is incomplete or contains unreviewed cases'
    return 1
  fi

  jq -e '
    .formatVersion as $formatVersion |
    ([.objectiveCases[].id] | length) == ([.objectiveCases[].id] | unique | length) and
    all(.objectiveCases[];
      (.area | type == "string" and length > 0) and
      (if $formatVersion == 2
       then .status == "verified" and (has("reason") | not)
       else (.status | IN("verified", "approved-deviation", "deferred-environment")) and
         (if .status == "deferred-environment"
          then (.reason | type == "string" and length > 0
            and (test("private Wayland") or test("VM")))
          elif .status == "approved-deviation"
          then (.reason | type == "string" and length > 0)
          else has("reason") | not
          end)
       end) and
      (.tests | type == "array" and length > 0 and
        all(.[]; type == "string" and length > 0))
    )
  ' "$manifest" >/dev/null || {
    rm -rf -- "$scratch"
    parity_validation_error \
      'objective case status is inconsistent with the manifest version'
    return 1
  }

  jq -r '[.entries[].tests[], .objectiveCases[].tests[]] | unique[]' \
    "$manifest" >"$scratch/references"
  while IFS= read -r reference; do
    if ! parity_reference_exists "$reference" "$repo_root" "$evidence_registry"; then
      rm -rf -- "$scratch"
      return 1
    fi
  done <"$scratch/references"

  while IFS=$'\t' read -r path pass_identity; do
    if ! rg -Fxq -- "$path#$pass_identity" "$scratch/references"; then
      rm -rf -- "$scratch"
      parity_validation_error "registered shell evidence is not required by the manifest: $path"
      return 1
    fi
  done < <(jq -r '.shellRunners[] | [.path, .passIdentity] | @tsv' "$evidence_registry")

  rm -rf -- "$scratch"
}

run_parity_shell_evidence() {
  local evidence_registry="$1"
  local repo_root="$2"
  local results_file="$3"
  local path pass_identity output

  while IFS=$'\t' read -r path pass_identity; do
    output="$(bash "$repo_root/$path")" || return 1
    printf '%s\n' "$output"
    if ! printf '%s\n' "$output" | rg -Fxq -- "$pass_identity"; then
      parity_validation_error "shell gate did not emit its anchored PASS identity: $path"
      return 1
    fi
    printf '%s#%s\n' "$path" "$pass_identity" >>"$results_file"
  done < <(jq -r '.shellRunners[] | [.path, .passIdentity] | @tsv' "$evidence_registry")
}

record_parity_qml_evidence() {
  local manifest="$1"
  local qml_log="$2"
  local results_file="$3"
  local reference selector

  while IFS= read -r reference; do
    parity_reference_parts "$reference"
    [[ "$PARITY_REFERENCE_PATH" == tests/qml/* ]] || continue
    selector="$PARITY_REFERENCE_SELECTOR"
    if ! rg -q "^PASS[[:space:]]*: .*::$selector\\(\\)$" "$qml_log"; then
      parity_validation_error "QML test did not produce a PASS result: $reference"
      return 1
    fi
    printf '%s\n' "$reference" >>"$results_file"
  done < <(jq -r '[.entries[].tests[], .objectiveCases[].tests[]] | unique[]' "$manifest")
}

validate_parity_evidence_results() {
  local manifest="$1"
  local results_file="$2"
  local scratch
  scratch="$(mktemp -d)" || return 1
  jq -r '[.entries[].tests[], .objectiveCases[].tests[]] | unique[]' "$manifest" \
    | LC_ALL=C sort >"$scratch/required"
  LC_ALL=C sort -u "$results_file" >"$scratch/results"
  if ! diff -u "$scratch/required" "$scratch/results"; then
    rm -rf -- "$scratch"
    parity_validation_error 'runtime evidence results do not cover every manifest reference'
    return 1
  fi
  rm -rf -- "$scratch"
  printf 'PASS: every parity reference produced executable runner evidence\n'
}
