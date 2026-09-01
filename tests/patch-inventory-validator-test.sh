#!/usr/bin/env bash
set -euo pipefail

source_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
validator="$source_root/tests/patch-inventory.sh"
fixture="$(mktemp -d)"
trap 'rm -rf -- "$fixture"' EXIT

git -C "$fixture" init -q
git -C "$fixture" config user.name 'Sleepy Test'
git -C "$fixture" config user.email 'sleepy-test@example.invalid'
mkdir -p "$fixture/src" "$fixture/tests"
printf 'initial\n' >"$fixture/src/shell.qml"
printf '#!/usr/bin/env bash\nprintf "PASS: fixture\\n"\n' >"$fixture/tests/gate.sh"
chmod +x "$fixture/tests/gate.sh"
git -C "$fixture" add src tests/gate.sh
git -C "$fixture" commit -qm baseline
baseline="$(git -C "$fixture" rev-parse HEAD)"
printf 'modified\n' >"$fixture/src/shell.qml"

cat >"$fixture/tests/patch-inventory.json" <<'JSON'
{
  "formatVersion": 1,
  "upstreamRevision": "24aa15eefdb146350d2548c0a015b04eddbd1008",
  "entries": [{
    "path": "src/shell.qml",
    "upstreamPath": "shell.qml",
    "category": "identity",
    "reason": "fixture identity conversion",
    "tests": ["tests/gate.sh#PASS: fixture"]
  }]
}
JSON

validate_fixture() {
  SLEEPY_PATCH_REPO_ROOT="$fixture" \
  SLEEPY_PATCH_INVENTORY="$fixture/tests/patch-inventory.json" \
  SLEEPY_PATCH_IMPORT_COMMIT="$baseline" \
    bash "$validator"
}

expect_rejected() {
  local label="$1"
  if validate_fixture >/dev/null 2>&1; then
    printf 'FAIL: patch inventory validator accepted %s\n' "$label" >&2
    exit 1
  fi
}

validate_fixture >/dev/null

jq '.entries[0].unknown = true' "$fixture/tests/patch-inventory.json" \
  >"$fixture/tests/invalid.json"
mv "$fixture/tests/invalid.json" "$fixture/tests/patch-inventory.json"
expect_rejected 'an unknown entry key'

jq 'del(.entries[0].unknown) | .entries[0].path = "src/missing.qml"' \
  "$fixture/tests/patch-inventory.json" >"$fixture/tests/invalid.json"
mv "$fixture/tests/invalid.json" "$fixture/tests/patch-inventory.json"
expect_rejected 'a source pattern with no match'

jq '.entries[0].path = "src/shell.qml" | .entries += [.entries[0]]' \
  "$fixture/tests/patch-inventory.json" >"$fixture/tests/invalid.json"
mv "$fixture/tests/invalid.json" "$fixture/tests/patch-inventory.json"
expect_rejected 'a duplicate path'

jq '.entries = []' "$fixture/tests/patch-inventory.json" \
  >"$fixture/tests/invalid.json"
mv "$fixture/tests/invalid.json" "$fixture/tests/patch-inventory.json"
expect_rejected 'an unclassified modified source file'

printf 'PASS: patch inventory validator rejects incomplete and ambiguous inventories\n'
