#!/usr/bin/env bash
set -euo pipefail

scenarios=
output_root=
driver="${SLEEPY_REFERENCE_DRIVER:-}"
capture_output="${SLEEPY_REFERENCE_OUTPUT:-DP-1}"

while (($#)); do
  case "$1" in
    --scenarios) scenarios="${2:?}"; shift 2 ;;
    --output) output_root="${2:?}"; shift 2 ;;
    --driver) driver="${2:?}"; shift 2 ;;
    --capture-output) capture_output="${2:?}"; shift 2 ;;
    *) printf 'unknown capture argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done

[[ -f "$scenarios" && -n "$output_root" && -x "$driver" ]] || {
  printf 'capture requires --scenarios, --output, and an executable --driver\n' >&2
  exit 2
}
command -v grim >/dev/null
command -v jq >/dev/null
mkdir -p "$output_root"

while IFS= read -r scenario_id; do
  scenario_dir="$output_root/$scenario_id"
  mkdir -p "$scenario_dir"
  while IFS= read -r action; do
    "$driver" "$scenario_id" "$action"
  done < <(jq -r --arg id "$scenario_id" '.scenarios[] | select(.id == $id) | .actions[]' "$scenarios")

  kind="$(jq -r --arg id "$scenario_id" '.scenarios[] | select(.id == $id) | .kind' "$scenarios")"
  if [[ "$kind" == still ]]; then
    grim -o "$capture_output" "$scenario_dir/frame.png"
    continue
  fi

  previous=0
  timeline="$scenario_dir/timeline.json"
  printf '{"frames":[' >"$timeline"
  separator=
  index=0
  while IFS= read -r timestamp; do
    delay=$((timestamp - previous))
    if ((delay > 0)); then
      sleep "0.$(printf '%03d' "$delay")"
    fi
    frame="$(printf '%03d.png' "$index")"
    grim -o "$capture_output" "$scenario_dir/$frame"
    printf '%s{"file":"%s","timestampMs":%d}' "$separator" "$frame" "$timestamp" >>"$timeline"
    separator=,
    previous=$timestamp
    index=$((index + 1))
  done < <(jq -r --arg id "$scenario_id" '.scenarios[] | select(.id == $id) | .frameTimestampsMs[]' "$scenarios")
  printf ']}\n' >>"$timeline"
done < <(jq -r '.scenarios[].id' "$scenarios")
