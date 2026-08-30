#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
inventory="$root/UPSTREAM.json"

usage() {
  printf 'usage: %s --source VERIFIED_SHELL_CHECKOUT\n' "${0##*/}" >&2
  exit 2
}

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

[[ $# -eq 2 && $1 == --source && -n $2 ]] || usage
source_root="$(cd "$2" 2>/dev/null && pwd -P)" || fail 'source checkout is unavailable'

repository="$(jq -er '.source.repository' "$inventory")"
tag="$(jq -er '.source.tag' "$inventory")"
tag_object="$(jq -er '.source.tagObject' "$inventory")"
commit="$(jq -er '.source.commit' "$inventory")"
license="$(jq -er '.source.license' "$inventory")"
destination="$(jq -er '.import.destination' "$inventory")"

[[ $license == GPL-3.0-only ]] || fail 'inventory must require GPL-3.0-only'
[[ $destination != /* && $destination != *..* ]] || fail 'inventory destination is unsafe'

git -C "$source_root" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || fail 'source is not a Git checkout'

origin="$(git -C "$source_root" remote get-url origin 2>/dev/null || true)"
case "$origin" in
  "$repository"|"$repository.git") ;;
  *) fail 'source repository is not the approved Caelestia Shell repository' ;;
esac

actual_commit="$(git -C "$source_root" rev-parse HEAD)"
[[ $actual_commit == "$commit" ]] || fail 'source commit is not approved'

actual_tag_object="$(git -C "$source_root" rev-parse "refs/tags/$tag" 2>/dev/null)" \
  || fail 'approved tag is unavailable locally'
[[ $actual_tag_object == "$tag_object" ]] || fail 'source tag object is not approved'

actual_tag="$(git -C "$source_root" describe --exact-match --tags HEAD 2>/dev/null)" \
  || fail 'source commit is not exactly at an approved tag'
[[ $actual_tag == "$tag" ]] || fail 'source tag is not approved'

[[ -z "$(git -C "$source_root" status --porcelain --untracked-files=all)" ]] \
  || fail 'source checkout is dirty'

[[ -f "$source_root/LICENSE" ]] || fail 'source checkout has no LICENSE file'
rg -F 'GNU GENERAL PUBLIC LICENSE' "$source_root/LICENSE" >/dev/null \
  || fail 'source LICENSE is not GPL'
rg -F 'Version 3, 29 June 2007' "$source_root/LICENSE" >/dev/null \
  || fail 'source LICENSE is not GPL-3.0-only'

mapfile -t approved_paths < <(jq -er '.import.paths[]' "$inventory")
[[ ${#approved_paths[@]} -gt 0 ]] || fail 'inventory has no approved import paths'
for path in "${approved_paths[@]}"; do
  [[ $path != /* && $path != *..* && $path != *$'\n'* ]] \
    || fail "inventory path is unsafe: $path"
  [[ -e "$source_root/$path" ]] || fail "approved source path is missing: $path"
done

staging_root="$(mktemp -d "$root/.import-upstream.XXXXXX")"
cleanup() {
  rm -rf "$staging_root"
}
trap cleanup EXIT

for path in "${approved_paths[@]}"; do
  cp -a "$source_root/$path" "$staging_root/$path"
done

mkdir -p "$root/$destination"
for path in "${approved_paths[@]}"; do
  cp -a "$staging_root/$path" "$root/$destination/$path"
done
