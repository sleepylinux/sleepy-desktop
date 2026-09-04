#!/usr/bin/env sh

cat ~/.local/state/sleepy/sequences.txt 2>/dev/null

exec "$@"
