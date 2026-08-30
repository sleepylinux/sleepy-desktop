#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
importer="$root/scripts/import-upstream.sh"

cleanup() {
  rm -rf "$test_root"
}

test_root="$(mktemp -d)"
trap cleanup EXIT

jq -e '
  .source.repository == "https://github.com/caelestia-dots/shell" and
  .source.tag == "v2.4.0" and
  .source.tagObject == "15c41f3e19818199f653aa7dcec81d49affd7152" and
  .source.commit == "24aa15eefdb146350d2548c0a015b04eddbd1008" and
  .source.license == "GPL-3.0-only" and
  .dependencies.quickshell.rev == "0fed22a2c47d9568ddf13cf61586b3f2ac4378a2" and
  .dependencies.quickshell.narHash == "sha256-OZdLL1rMR9kjTFZroOODeyQ0u6nrSxcFHlK6JUi+R/c=" and
  .dependencies.m3shapes.rev == "32ad9ce328bb77ed349b40a3be10ee9ea610b8ab" and
  .dependencies.m3shapes.narHash == "sha256-YZelgEZflFNwGutX4/tIzBdbOeghJgE2oDw0uWYGxns="
' "$root/UPSTREAM.json" >/dev/null
! rg -n 'caelestia-dots/caelestia' "$root/src" "$root/UPSTREAM.json"
rg -F 'Caelestia Shell' "$root/NOTICE" >/dev/null

expect_rejection() {
  local label="$1"
  local source="$2"
  local expected_reason="$3"
  local output="$test_root/$label-output"

  if "$importer" --source "$source" >"$output" 2>&1; then
    printf 'FAIL: importer accepted %s source\n' "$label" >&2
    exit 1
  fi
  rg -F "$expected_reason" "$output" >/dev/null || {
    printf 'FAIL: importer rejected %s source for an unexpected reason\n' "$label" >&2
    cat "$output" >&2
    exit 1
  }
}

forbidden_source="$test_root/forbidden-source"
git init --quiet "$forbidden_source"
git -C "$forbidden_source" config user.name 'Sleepy provenance test'
git -C "$forbidden_source" config user.email 'provenance-test@example.invalid'
touch "$forbidden_source/LICENSE"
git -C "$forbidden_source" add LICENSE
git -C "$forbidden_source" commit --quiet -m fixture
git -C "$forbidden_source" remote add origin https://github.com/caelestia-dots/caelestia
expect_rejection forbidden-repository "$forbidden_source" \
  'source repository is not the approved Caelestia Shell repository'

wrong_revision_source="$test_root/wrong-revision-source"
git init --quiet "$wrong_revision_source"
git -C "$wrong_revision_source" config user.name 'Sleepy provenance test'
git -C "$wrong_revision_source" config user.email 'provenance-test@example.invalid'
touch "$wrong_revision_source/LICENSE"
git -C "$wrong_revision_source" add LICENSE
git -C "$wrong_revision_source" commit --quiet -m fixture
git -C "$wrong_revision_source" remote add origin https://github.com/caelestia-dots/shell
expect_rejection wrong-revision "$wrong_revision_source" 'source commit is not approved'
