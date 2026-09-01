#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/sleepy-qs-pin-validator.XXXXXX")"
cleanup() {
    rm -rf -- "$test_root"
}
trap cleanup EXIT

repository_copy="$test_root/repository"
cp -a "$repo_root" "$repository_copy"

python3 - "$repository_copy/flake.nix" <<'PY'
from pathlib import Path
import sys

flake = Path(sys.argv[1])
text = flake.read_text(encoding="utf-8")
needle = (
    "            readonly SLEEPY_TEST_QUICKSHELL=${quickshellWithModules}/bin/qs\n"
    "            export SLEEPY_TEST_QUICKSHELL\n"
)
if needle not in text:
    raise SystemExit("expected pinned Quickshell assignment was not found")
text = text.replace(
    needle,
    needle + "            SLEEPY_TEST_QUICKSHELL=/usr/bin/quickshell\n",
    1,
)
flake.write_text(text, encoding="utf-8")
PY

set +e
bash "$repository_copy/tests/dependencies.sh" >/dev/null 2>&1
status=$?
set -e
if [[ $status -eq 0 ]]; then
    printf 'FAIL: dependency validator accepted a later reassignment of the pinned Quickshell executable\n' >&2
    exit 1
fi

printf 'PASS: dependency validator rejects later Quickshell executable reassignment\n'
