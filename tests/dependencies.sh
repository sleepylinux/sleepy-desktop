#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
sdk_revision=2edbe8310eee69c40e4f75924da67a57942bd1c3
artwork_revision=bd0d9ac2261b4dc2c3ad41e6d3d898b22cda2a85
flake="$repository_root/flake.nix"
metadata_and_docs=("$flake" "$repository_root/README.md")

read_nix_block_attribute() {
  local block="$1"
  local attribute="$2"

  awk -v block="$block" -v attribute="$attribute" '
    $1 == block && $2 == "=" && $3 == "{" { in_block = 1; next }
    in_block && $1 == attribute && $2 == "=" {
      value = $3
      gsub(/[";]/, "", value)
      print value
      exit
    }
    in_block && $1 ~ /^}/ { exit }
  ' "$flake"
}

require_nix_block_attribute() {
  local block="$1"
  local attribute="$2"
  local expected="$3"
  local actual

  actual="$(read_nix_block_attribute "$block" "$attribute")"
  if [[ "$actual" != "$expected" ]]; then
    printf 'FAIL: %s.%s must be %s (got %s)\n' \
      "$block" "$attribute" "$expected" "${actual:-missing}" >&2
    exit 1
  fi
}

require_nix_block_attribute sleepy-sdk url "github:sleepylinux/sleepy-sdk/$sdk_revision"
require_nix_block_attribute sleepy-artwork url "github:sleepylinux/sleepy-artwork/$artwork_revision"
require_nix_block_attribute passthru sdkRevision "$sdk_revision"
require_nix_block_attribute passthru artworkRevision "$artwork_revision"

for revision in \
  4c4f7989b957f41f3748ddfb092b0348e2ba9e88 \
  7785ac5dac0daa6ac1a619f1e2a9a1b1d1374da1; do
  if rg -n -F "$revision" "${metadata_and_docs[@]}"; then
    printf 'FAIL: tracked dependency metadata/docs must not pin pre-GPL revision %s\n' \
      "$revision" >&2
    exit 1
  fi
done

rg -Fq "$sdk_revision" "$repository_root/README.md"
rg -Fq "$artwork_revision" "$repository_root/README.md"

if ! rg -Fq 'sleepy-artwork.checks.${system}.assets' "$flake"; then
  printf 'FAIL: desktop checks must consume exact sleepy-artwork checks.<system>.assets\n' >&2
  exit 1
fi

if ! rg -Fq "export SLEEPY_ARTWORK_ROOT='\${artworkRoot}'" "$flake"; then
  printf 'FAIL: qml check must test the exact installed artwork root\n' >&2
  exit 1
fi

if ! rg -Fq -- '--set QML_XHR_ALLOW_FILE_READ 1' "$flake"; then
  printf 'FAIL: packaged QML runners must allow their pinned local manifest read\n' >&2
  exit 1
fi

checks_attrset="$(
  sed -n '/^      checks = forAllSystems (system:/,/^        });$/p' "$flake" |
    sed -n '/^        {$/,/^        });$/p'
)"
mapfile -t check_names < <(
  sed -nE \
    -e 's/^          ([A-Za-z_][A-Za-z0-9_-]*)[[:space:]]*=.*/\1/p' \
    -e 's/^          "([^"]+)"[[:space:]]*=.*/\1/p' \
    <<< "$checks_attrset"
)
if [[ "${check_names[*]:-}" != "qml package preview" ]]; then
  printf 'FAIL: per-system desktop checks must expose exactly qml package preview, found: %s\n' \
    "${check_names[*]:-(none)}" >&2
  exit 1
fi

printf 'PASS: desktop dependency metadata pins reviewed GPL revisions\n'
