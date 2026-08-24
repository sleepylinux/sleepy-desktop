#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
sdk_revision=2edbe8310eee69c40e4f75924da67a57942bd1c3
artwork_revision=0dd59cc9d8a77700f7a415997e3dcde396f55e99

for file in flake.nix README.md; do
  source_file="$repository_root/$file"
  if ! rg -q "$sdk_revision" "$source_file"; then
    printf 'FAIL: %s must pin sleepy-sdk at %s\n' "$file" "$sdk_revision" >&2
    exit 1
  fi
  if ! rg -q "$artwork_revision" "$source_file"; then
    printf 'FAIL: %s must pin sleepy-artwork at %s\n' "$file" "$artwork_revision" >&2
    exit 1
  fi
done

if [[ "$(rg -o 'github:sleepylinux/sleepy-(sdk|artwork)/[0-9a-f]{40}' "$repository_root/flake.nix" | wc -l)" != 2 ]]; then
  printf 'FAIL: flake.nix must contain exactly two internal dependency pins\n' >&2
  exit 1
fi

if [[ "$(rg -o '[0-9a-f]{40}' "$repository_root/README.md" | wc -l)" != 2 ]]; then
  printf 'FAIL: README.md must document exactly the two internal dependency pins\n' >&2
  exit 1
fi

printf 'PASS: desktop dependency metadata pins reviewed GPL revisions\n'
