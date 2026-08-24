#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
sdk_revision=2edbe8310eee69c40e4f75924da67a57942bd1c3
artwork_revision=0dd59cc9d8a77700f7a415997e3dcde396f55e99
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

printf 'PASS: desktop dependency metadata pins reviewed GPL revisions\n'
