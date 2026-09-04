#!/usr/bin/env bash

copy_upstream_path() {
  local source_path="$1"
  local destination_root="$2"
  local name

  name="$(basename "$source_path")"
  mkdir -p "$destination_root"
  if [[ -d "$source_path" && ! -L "$source_path" ]]; then
    mkdir -p "$destination_root/$name"
    cp -a "$source_path"/. "$destination_root/$name/"
  else
    cp -a "$source_path" "$destination_root/$name"
  fi
}
