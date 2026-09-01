#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

if rg -n 'Theme\.ThemeTokens|Theme\.EffectsPolicy' "$repository_root/src/shell.qml"; then
  printf 'FAIL: modular shell must use the upstream native Tokens animation graph\n' >&2
  exit 1
fi
for animation_root in \
  "$repository_root/src/components/Anim.qml" \
  "$repository_root/src/components/AnchorAnim.qml"; do
  if ! rg -Fq 'Tokens.anim.durations' "$animation_root"; then
    printf 'FAIL: upstream animation component is detached from native Tokens: %s\n' \
      "${animation_root#"$repository_root"/}" >&2
    exit 1
  fi
done
if ! rg -Uq 'Theme\.ThemeTokens[[:space:]]*\{[^}]*effectsPolicy:[[:space:]]*effects' \
    "$repository_root/src/preview/main.qml"; then
  printf 'FAIL: legacy preview must retain its isolated EffectsPolicy tokens\n' >&2
  exit 1
fi

drawer_component="$repository_root/src/drawers/ControlCenterDrawer.qml"
if ! rg -q 'readonly property int transitionDuration:[[:space:]]*tokens\.motionDuration' \
    "$drawer_component" \
    || ! rg -q 'duration:[[:space:]]*root\.transitionDuration' \
      "$drawer_component"; then
  printf 'FAIL: ControlCenterDrawer transition must expose and use ThemeTokens duration\n' >&2
  exit 1
fi

mapfile -t animated_components < <(
  rg -l '(Number|Color)Animation' \
    "$repository_root/src/drawers" \
    "$repository_root/src/panels" \
    "$repository_root/src/widgets" \
    "$repository_root/src/preview" \
    --glob '*.qml' | sort
)
for animated_component in "${animated_components[@]}"; do
  if rg -n 'duration:[[:space:]]*[1-9][0-9]*' "$animated_component"; then
    printf 'FAIL: production animation uses a fixed nonzero duration: %s\n' \
      "${animated_component#"$repository_root"/}" >&2
    exit 1
  fi
  if ! rg -q 'duration:[[:space:]]*root\.(tokens\.motionDuration|transitionDuration)' \
      "$animated_component"; then
    printf 'FAIL: production animation does not follow ThemeTokens: %s\n' \
      "${animated_component#"$repository_root"/}" >&2
    exit 1
  fi
done

for exposed_component in \
  "$repository_root/src/widgets/ControlTile.qml" \
  "$repository_root/src/widgets/WorkspaceButton.qml"; do
  if ! rg -q 'readonly property int transitionDuration:[[:space:]]*tokens\.motionDuration' \
      "$exposed_component" \
      || ! rg -q 'duration:[[:space:]]*root\.transitionDuration' \
        "$exposed_component"; then
    printf 'FAIL: component transition must expose and use ThemeTokens: %s\n' \
      "${exposed_component#"$repository_root"/}" >&2
    exit 1
  fi
done

printf 'PASS: production animation durations follow injected EffectsPolicy tokens\n'
