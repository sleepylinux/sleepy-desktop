#!/usr/bin/env bash
set -euo pipefail

default_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
repo_root="${SLEEPY_PATCH_REPO_ROOT:-$default_repo_root}"
inventory="${SLEEPY_PATCH_INVENTORY:-$repo_root/tests/patch-inventory.json}"
import_commit="${SLEEPY_PATCH_IMPORT_COMMIT:-d5e10fb9b765afbd6c56c2b359875e8a66584ff3}"

if [[ ! -f "$inventory" ]]; then
  printf 'FAIL: tests/patch-inventory.json is missing\n' >&2
  exit 1
fi

jq -e '
  .formatVersion == 1 and
  .upstreamRevision == "24aa15eefdb146350d2548c0a015b04eddbd1008" and
  (.entries | type == "array" and length > 0) and
  ([.entries[].path] | length) == ([.entries[].path] | unique | length) and
  all(.entries[];
    (keys | sort) == ["category", "path", "reason", "tests", "upstreamPath"] and
    (.path | type == "string" and test("^src/[A-Za-z0-9_./*-]+$") and
      ((contains("*") | not) or test("/\\*\\*$"))) and
    (.upstreamPath == null or
      (.upstreamPath | type == "string" and test("^[A-Za-z0-9_./*-]+$"))) and
    (.category | IN("identity", "packaging", "compatibility", "security", "branding")) and
    (.reason | type == "string" and length > 0) and
    (.tests | type == "array" and length > 0 and
      all(.[]; type == "string" and test("^tests/[A-Za-z0-9_./-]+\\.(sh|qml)#.+$")))
  )
' "$inventory" >/dev/null || {
  printf 'FAIL: patch inventory schema is invalid\n' >&2
  exit 1
}

mapfile -t patterns < <(jq -r '.entries[].path' "$inventory")
mapfile -t source_files < <(
  find "$repo_root/src" -type f -printf '%P\n' | sed 's#^#src/#'
)

for pattern in "${patterns[@]}"; do
  match_pattern="$pattern"
  if [[ "$match_pattern" == *'/**' ]]; then
    match_pattern="${match_pattern%/**}/*"
  fi
  matched=0
  for candidate in "${source_files[@]}"; do
    if [[ "$candidate" == $match_pattern ]]; then
      matched=1
      break
    fi
  done
  if [[ $matched -eq 0 ]]; then
    printf 'FAIL: patch inventory path matches no source file: %s\n' "$pattern" >&2
    exit 1
  fi
done

while IFS= read -r reference; do
  reference_path="${reference%%#*}"
  if [[ ! -f "$repo_root/$reference_path" ]]; then
    printf 'FAIL: patch inventory test reference does not exist: %s\n' "$reference" >&2
    exit 1
  fi
done < <(jq -r '.entries[].tests[]' "$inventory" | LC_ALL=C sort -u)

while IFS= read -r changed; do
  covered=0
  for pattern in "${patterns[@]}"; do
    match_pattern="$pattern"
    if [[ "$match_pattern" == *'/**' ]]; then
      match_pattern="${match_pattern%/**}/*"
    fi
    if [[ "$changed" == $match_pattern ]]; then
      covered=1
      break
    fi
  done
  if [[ $covered -eq 0 ]]; then
    printf 'FAIL: modified imported source is missing from patch inventory: %s\n' "$changed" >&2
    exit 1
  fi
done < <(
  {
    git -C "$repo_root" diff --name-only --diff-filter=ACMRT "$import_commit"..HEAD -- src
    git -C "$repo_root" diff --name-only --diff-filter=ACMRT -- src
    git -C "$repo_root" diff --cached --name-only --diff-filter=ACMRT -- src
  } | LC_ALL=C sort -u
)

printf 'PASS: every Sleepy patch to imported shell source is classified\n'
