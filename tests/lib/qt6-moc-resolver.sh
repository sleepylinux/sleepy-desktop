#!/usr/bin/env bash

is_qt6_moc() {
    local candidate="$1"
    local version

    [[ -n "$candidate" && -x "$candidate" ]] || return 1
    version="$("$candidate" -v 2>&1 || true)"
    [[ "$version" == "moc 6."* ]]
}

qt6_moc_from_libexec() {
    local libexec_dir="$1"
    local candidate

    [[ -n "$libexec_dir" && "$libexec_dir" == /* ]] || return 1
    [[ "$libexec_dir" != *$'\n'* && "$libexec_dir" != *$'\r'* ]] || return 1
    candidate="${libexec_dir%/}/moc"
    is_qt6_moc "$candidate" || return 1
    printf '%s\n' "$candidate"
}

resolve_qt6_moc() {
    local candidate
    local libexec_dir
    local qtpaths_binary
    local qtpaths_name
    local resolved

    candidate="$(command -v moc || true)"
    if is_qt6_moc "$candidate"; then
        printf '%s\n' "$candidate"
        return 0
    fi

    for qtpaths_name in qtpaths6 qtpaths-qt6 qtpaths; do
        qtpaths_binary="$(command -v "$qtpaths_name" || true)"
        [[ -n "$qtpaths_binary" ]] || continue
        libexec_dir="$(
            "$qtpaths_binary" --query QT_INSTALL_LIBEXECS 2>/dev/null || true
        )"
        if resolved="$(qt6_moc_from_libexec "$libexec_dir")"; then
            printf '%s\n' "$resolved"
            return 0
        fi
    done

    if command -v pkg-config >/dev/null 2>&1; then
        libexec_dir="$(
            pkg-config --variable=libexecdir Qt6Core 2>/dev/null || true
        )"
        if resolved="$(qt6_moc_from_libexec "$libexec_dir")"; then
            printf '%s\n' "$resolved"
            return 0
        fi
    fi

    for candidate in \
        /usr/lib/qt6/libexec/moc \
        /usr/lib/qt6/bin/moc \
        /usr/lib/qt6/moc \
        /usr/bin/moc; do
        if is_qt6_moc "$candidate"; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}
