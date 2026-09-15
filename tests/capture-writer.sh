#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
read -r -a qt_flags <<< "$(pkg-config --cflags --libs Qt6Core Qt6Gui)"
c++ -std=c++20 -O2 -D_FORTIFY_SOURCE=3 -fPIC -Wall -Wextra -Werror -pthread \
  "$repo_root/tests/capture_writer.cpp" \
  "$repo_root/src/plugin/src/Sleepy/capturewriter.cpp" \
  "${qt_flags[@]}" -o "$scratch/capture-writer"
"$scratch/capture-writer"
python3 "$repo_root/tests/test_capture_wrapper.py"
