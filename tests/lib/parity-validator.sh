#!/usr/bin/env bash

parity_validation_error() {
  printf 'FAIL: %s\n' "$*" >&2
  return 1
}

parity_reference_exists() {
  local reference="$1"
  local repo_root="$2"
  local path selector resolved

  path="${reference%%#*}"
  selector=""
  if [[ "$reference" == *'#'* ]]; then
    selector="${reference#*#}"
  fi

  [[ -n "$path" && "$path" == tests/* && "$path" != *'/../'* \
      && "$path" != ../* && "$path" != */.. && "$path" != *//* ]] \
    || parity_validation_error "invalid test reference: $reference" || return 1
  resolved="$repo_root/$path"
  [[ -f "$resolved" ]] \
    || parity_validation_error "test reference does not exist: $reference" || return 1
  if [[ "$reference" == *'#'* ]]; then
    [[ -n "$selector" ]] \
      || parity_validation_error "empty test selector: $reference" || return 1
    rg -F -q -- "$selector" "$resolved" \
      || parity_validation_error "test selector does not exist: $reference" || return 1
  fi
}

validate_parity_manifest() {
  local manifest="$1"
  local inventory_file="$2"
  local required_cases_file="$3"
  local repo_root="$4"
  local scratch reference

  command -v jq >/dev/null 2>&1 \
    || parity_validation_error 'jq is required' || return 1
  [[ -f "$manifest" ]] \
    || parity_validation_error 'tests/parity-manifest.json is missing' || return 1
  [[ -f "$inventory_file" && -f "$required_cases_file" ]] \
    || parity_validation_error 'validator inputs are missing' || return 1

  jq -e '
    .formatVersion == 1 and
    (.upstreamRevision | type == "string" and length > 0) and
    (.entries | type == "array" and length > 0) and
    (.objectiveCases | type == "array" and length > 0) and
    (.referenceComparison | type == "object")
  ' "$manifest" >/dev/null \
    || parity_validation_error 'parity manifest top-level contract is invalid' || return 1

  jq -e '
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
  ' "$manifest" >/dev/null || {
    parity_validation_error \
      'exact upstream reference capture must remain explicitly deferred to private Wayland/VM'
    return 1
  }

  scratch="$(mktemp -d)" || return 1
  jq -r '.entries[].path' "$manifest" | LC_ALL=C sort >"$scratch/declared-paths"
  LC_ALL=C sort "$inventory_file" >"$scratch/actual-paths"
  if ! diff -u "$scratch/actual-paths" "$scratch/declared-paths"; then
    rm -rf -- "$scratch"
    parity_validation_error \
      'manifest must contain every imported QML/C++ module or service exactly once'
    return 1
  fi

  jq -e '
    ([.entries[].path] | length) == ([.entries[].path] | unique | length) and
    all(.entries[];
      (.path | type == "string" and length > 0) and
      (.disposition | IN("render", "move", "rewrite", "drop-with-reason")) and
      (.sleepyOwner | IN("sleepy-desktop", "sleepy-session", "none")) and
      (.protocol | type == "string" and length > 0) and
      (.degradedState | type == "string" and length > 0) and
      (.tests | type == "array" and length > 0 and
        all(.[]; type == "string" and length > 0)) and
      (if .disposition == "drop-with-reason"
        then (.approvedDeviation | type == "string" and length > 0)
        else has("approvedDeviation") | not
       end)
    )
  ' "$manifest" >/dev/null || {
    rm -rf -- "$scratch"
    parity_validation_error 'an inventory entry is incomplete or unclassified'
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
    ([.objectiveCases[].id] | length) == ([.objectiveCases[].id] | unique | length) and
    all(.objectiveCases[];
      (.area | type == "string" and length > 0) and
      (.status | IN("verified", "deferred-environment")) and
      (.tests | type == "array" and length > 0 and
        all(.[]; type == "string" and length > 0)) and
      (if .status == "deferred-environment"
        then (.reason | type == "string" and length > 0)
        else has("reason") | not
       end)
    )
  ' "$manifest" >/dev/null || {
    rm -rf -- "$scratch"
    parity_validation_error \
      'objective cases need verified tests or an explicit environment deferral'
    return 1
  }

  jq -r '[.entries[].tests[], .objectiveCases[].tests[]] | unique[]' \
    "$manifest" >"$scratch/references"
  while IFS= read -r reference; do
    if ! parity_reference_exists "$reference" "$repo_root"; then
      rm -rf -- "$scratch"
      return 1
    fi
  done <"$scratch/references"

  rm -rf -- "$scratch"
}
