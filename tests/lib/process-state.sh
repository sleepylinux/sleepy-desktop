#!/usr/bin/env bash

sleepy_pid_is_running() {
    local pid=$1 stat_line state
    kill -0 "$pid" 2>/dev/null || return 1
    [[ -r "/proc/$pid/stat" ]] || return 0
    stat_line="$(<"/proc/$pid/stat")"
    state="${stat_line##*) }"
    state="${state%% *}"
    [[ "$state" != Z && "$state" != X ]]
}
