#!/usr/bin/env bash
set -euo pipefail
umask 077

invalid() {
  printf 'Invalid capture helper arguments\n' >&2
  exit 64
}

job_id= output_id= output_path= output_fd=
while (($#)); do
  (($# >= 2)) || invalid
  case "$1" in
    --job-id) [[ -z "$job_id" ]] || invalid; job_id=$2 ;;
    --output-id) [[ -z "$output_id" ]] || invalid; output_id=$2 ;;
    --output) [[ -z "$output_path" ]] || invalid; output_path=$2 ;;
    --output-fd) [[ -z "$output_fd" ]] || invalid; output_fd=$2 ;;
    *) invalid ;;
  esac
  shift 2
done
[[ "$job_id" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]] || invalid
[[ "$output_id" =~ ^output:[A-Za-z0-9_.-]{1,128}$ ]] || invalid
[[ "$output_path" == "/run/user/$EUID/sleepy/captures/screenshot-$job_id.png" ]] || invalid
[[ "$output_fd" == 4 ]] || invalid
[[ "${SLEEPY_CAPTURE_RUNNER:-}" == /* && -x "$SLEEPY_CAPTURE_RUNNER" ]] || invalid
[[ "${SLEEPY_CAPTURE_QML:-}" == /* && -f "$SLEEPY_CAPTURE_QML" ]] || invalid

export SLEEPY_CAPTURE_JOB_ID="$job_id"
export SLEEPY_CAPTURE_OUTPUT_ID="$output_id"
export SLEEPY_CAPTURE_OUTPUT_PATH="$output_path"
export SLEEPY_CAPTURE_OUTPUT_FD=4
# Only CUtils.captureJobStatus writes the protocol descriptor. Ordinary Qt logs
# go to the separately bounded stderr stream, never into the JSONL channel.
exec 3>&1
export SLEEPY_CAPTURE_STATUS_FD=3
exec 1>&2
exec "$SLEEPY_CAPTURE_RUNNER" -p "$SLEEPY_CAPTURE_QML"
