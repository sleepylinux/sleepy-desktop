#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
license="$repository_root/LICENSE"
expected_size=34674
expected_sha256=fb981668c18a279e285fc4d83fba1e836cc84dd4daa73c9697d3cfd2d8aca6e0

if [[ ! -f "$license" ]]; then
  printf 'FAIL: LICENSE is missing: %s\n' "$license" >&2
  exit 1
fi

if ! command -v sha256sum >/dev/null 2>&1; then
  printf 'FAIL: sha256sum is required to verify the canonical GNU GPLv3 text\n' >&2
  exit 1
fi

actual_size="$(wc -c < "$license")"
actual_sha256="$(sha256sum "$license")"
actual_sha256="${actual_sha256%% *}"

if [[ "$actual_size" != "$expected_size" || "$actual_sha256" != "$expected_sha256" ]]; then
  printf 'FAIL: LICENSE must be the canonical GNU GPLv3 text (size %s, SHA-256 %s)\n' \
    "$expected_size" "$expected_sha256" >&2
  exit 1
fi

if ! rg -q 'license = pkgs\.lib\.licenses\.gpl3Only;' "$repository_root/flake.nix"; then
  printf 'FAIL: Nix package metadata must declare GPL-3.0-only\n' >&2
  exit 1
fi

if rg -n -i 'licenses\.mit|gpl3Plus|GPL-3\.0-or-later' "$repository_root/flake.nix"; then
  printf 'FAIL: package metadata must not use MIT or GPL-or-later\n' >&2
  exit 1
fi

printf 'PASS: GPL-3.0-only license text and metadata are verified\n'
