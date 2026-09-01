#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/sleepy-moc-resolver.XXXXXX")"
cleanup() {
    rm -rf -- "$test_root"
}
trap cleanup EXIT

source "$repo_root/tests/lib/qt6-moc-resolver.sh"

make_moc() {
    local path="$1"
    local version="$2"
    mkdir -p "$(dirname "$path")"
    printf '#!/bin/sh\nprintf '\''%%s\\n'\'' '\''%s'\''\n' "$version" >"$path"
    chmod 0700 "$path"
}

path_bin="$test_root/path-bin"
mkdir -p "$path_bin"
make_moc "$path_bin/moc" 'moc 6.11.1'
cat >"$path_bin/qtpaths6" <<SH
#!/bin/sh
: >'$test_root/qtpaths-ran'
exit 99
SH
chmod 0700 "$path_bin/qtpaths6"
resolved="$(PATH="$path_bin" resolve_qt6_moc)"
[[ "$resolved" == "$path_bin/moc" ]]
[[ ! -e "$test_root/qtpaths-ran" ]]

metadata_root="$test_root/Qt tools/libexec"
make_moc "$metadata_root/moc" 'moc 6.11.1'
qtpaths_bin="$test_root/qtpaths-bin"
mkdir -p "$qtpaths_bin"
cat >"$qtpaths_bin/qtpaths6" <<SH
#!/bin/sh
if [ "\$1" = --query ] && [ "\$2" = QT_INSTALL_LIBEXECS ]; then
    printf '%s\\n' '$metadata_root'
    exit 0
fi
exit 2
SH
chmod 0700 "$qtpaths_bin/qtpaths6"
resolved="$(PATH="$qtpaths_bin" resolve_qt6_moc)"
[[ "$resolved" == "$metadata_root/moc" ]]

pkg_metadata_root="$test_root/pkg Qt/libexec"
make_moc "$pkg_metadata_root/moc" 'moc 6.11.1'
pkg_bin="$test_root/pkg-bin"
mkdir -p "$pkg_bin"
cat >"$pkg_bin/pkg-config" <<SH
#!/bin/sh
if [ "\$1" = --variable=libexecdir ] && [ "\$2" = Qt6Core ]; then
    printf '%s\\n' '$pkg_metadata_root'
    exit 0
fi
exit 2
SH
chmod 0700 "$pkg_bin/pkg-config"
resolved="$(PATH="$pkg_bin" resolve_qt6_moc)"
[[ "$resolved" == "$pkg_metadata_root/moc" ]]

wrong_root="$test_root/wrong/libexec"
make_moc "$wrong_root/moc" 'moc 5.15.19'
if qt6_moc_from_libexec "" >/dev/null 2>&1 \
        || qt6_moc_from_libexec "relative/libexec" >/dev/null 2>&1 \
        || qt6_moc_from_libexec "$wrong_root" >/dev/null 2>&1 \
        || qt6_moc_from_libexec "$metadata_root"$'\nignored' >/dev/null 2>&1; then
    printf 'FAIL: empty, relative, wrong-version, or multiline metadata was accepted\n' >&2
    exit 1
fi

fallback_bin="$test_root/fallback-bin"
mkdir -p "$fallback_bin"
cat >"$fallback_bin/qtpaths6" <<'SH'
#!/bin/sh
exit 0
SH
cat >"$fallback_bin/pkg-config" <<SH
#!/bin/sh
printf '%s\\n' '$pkg_metadata_root'
SH
chmod 0700 "$fallback_bin/qtpaths6" "$fallback_bin/pkg-config"
resolved="$(PATH="$fallback_bin" resolve_qt6_moc)"
[[ "$resolved" == "$pkg_metadata_root/moc" ]]

printf 'PASS: Qt 6 moc resolver handles PATH, Nix metadata, quoted paths, and invalid metadata\n'
