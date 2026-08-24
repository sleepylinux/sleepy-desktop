#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
authoritative_license="${SLEEPY_AUTHORITATIVE_LICENSE:-$repository_root/../../sleepy/LICENSE}"

if [[ ! -f "$authoritative_license" ]]; then
  printf 'FAIL: authoritative GPLv3 license is missing: %s\n' "$authoritative_license" >&2
  exit 1
fi

if ! cmp -s "$repository_root/LICENSE" "$authoritative_license"; then
  printf 'FAIL: LICENSE must match the authoritative Sleepy GPLv3 text byte-for-byte\n' >&2
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
