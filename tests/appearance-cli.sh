#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
scratch="$(mktemp -d /tmp/sleepy-appearance-cli.XXXXXX)"
trap 'rm -rf -- "$scratch"' EXIT

export XDG_CONFIG_HOME="$scratch/config"
export XDG_DATA_HOME="$scratch/data"
export XDG_STATE_HOME="$scratch/state"
export XDG_CACHE_HOME="$scratch/cache"
export XDG_PICTURES_DIR="$scratch/pictures"
export PYTHONPATH="$repo_root/appearance-cli/src"
export PYTHONDONTWRITEBYTECODE=1

sleepy_cli() {
  if [[ -n "${SLEEPY_APPEARANCE_CLI:-}" ]]; then
    "$SLEEPY_APPEARANCE_CLI" "$@"
  else
    python3 -m sleepy "$@"
  fi
}

legacy_identity='caele''stia'
if rg -n -i "$legacy_identity" "$repo_root/appearance-cli/src" "$repo_root/appearance-cli/pyproject.toml"; then
  printf 'FAIL: appearance helper retains legacy runtime identity\n' >&2
  exit 1
fi
if rg -n 'shell[[:space:]]*=[[:space:]]*True' "$repo_root/appearance-cli/src"; then
  printf 'FAIL: appearance helper executes shell strings\n' >&2
  exit 1
fi

sleepy_cli scheme list >"$scratch/schemes.json"
python3 - "$scratch/schemes.json" <<'PY'
import json, pathlib, sys
schemes = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert "sleepy" in schemes and "catppuccin" in schemes and "dynamic" in schemes
assert all(isinstance(flavours, dict) for flavours in schemes.values())
assert schemes["sleepy"] and schemes["catppuccin"]
PY

sleepy_cli scheme set -v expressive
test "$(sleepy_cli scheme get -v)" = expressive

mkdir -p "$XDG_PICTURES_DIR/Wallpapers"
python3 - "$XDG_PICTURES_DIR/Wallpapers/test.png" <<'PY'
from PIL import Image
import sys
Image.new("RGB", (32, 32), (44, 35, 66)).save(sys.argv[1])
PY
sleepy_cli wallpaper -f "$XDG_PICTURES_DIR/Wallpapers/test.png" --no-smart
test "$(sleepy_cli wallpaper)" = "$XDG_PICTURES_DIR/Wallpapers/test.png"
sleepy_cli wallpaper -p "$XDG_PICTURES_DIR/Wallpapers/test.png" --no-smart \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["name"] == "dynamic" and d["colours"]'

printf 'PASS: Sleepy-owned appearance CLI lists/applies schemes and persists/analyzes wallpapers\n'
