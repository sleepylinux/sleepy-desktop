#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/sleepy-socket-env.XXXXXX")"
cleanup() {
    rm -rf -- "$test_root"
}
trap cleanup EXIT

repository_copy="$test_root/repository"
cp -a "$repo_root" "$repository_copy"
cp "$repo_root/flake.nix" "$test_root/flake.nix"
cp "$repo_root/tests/desktop-client-socket-contract.sh" "$test_root/socket-contract.sh"

reset_copy() {
    cp "$test_root/flake.nix" "$repository_copy/flake.nix"
    cp "$test_root/socket-contract.sh" \
        "$repository_copy/tests/desktop-client-socket-contract.sh"
}

mutate() {
    local mode="$1"
    python3 - "$repository_copy/flake.nix" \
        "$repository_copy/tests/desktop-client-socket-contract.sh" "$mode" <<'PY'
from pathlib import Path
import sys

flake_path = Path(sys.argv[1])
runner_path = Path(sys.argv[2])
mode = sys.argv[3]

dependencies = {
    "compiler": "        pkgs.stdenv.cc\n",
    "pkg-config": "        pkgs.pkg-config\n",
    "qt-core-moc": "        pkgs.qt6.qtbase\n",
    "qt-qml": "        pkgs.qt6.qtdeclarative\n",
}
flake_text = flake_path.read_text(encoding="utf-8")
runner_text = runner_path.read_text(encoding="utf-8")

if mode in dependencies:
    needle = dependencies[mode]
    block_start = flake_text.index("      socketContractNativeInputs = pkgs: [\n")
    block_end = flake_text.index("      ];\n", block_start) + len("      ];\n")
    socket_inputs = flake_text[block_start:block_end]
    if socket_inputs.count(needle) != 1:
        raise SystemExit(f"expected one socket dependency line for {mode}")
    socket_inputs = socket_inputs.replace(needle, "", 1)
    flake_text = (
        flake_text[:block_start] + socket_inputs + flake_text[block_end:]
    )
elif mode == "qml-consumer":
    needle = "] ++ socketContractNativeInputs pkgs;"
    if flake_text.count(needle) != 1:
        raise SystemExit("expected one qml socket input consumer")
    flake_text = flake_text.replace(needle, "];", 1)
elif mode == "dev-shell-consumer":
    needle = "packages = socketContractNativeInputs pkgs;"
    if flake_text.count(needle) != 1:
        raise SystemExit("expected one dev-shell socket input consumer")
    flake_text = flake_text.replace(needle, "packages = [];", 1)
elif mode == "path-moc":
    needle = 'moc_binary="$(command -v moc || true)"'
    if runner_text.count(needle) != 1:
        raise SystemExit("expected one PATH moc discovery")
    runner_text = runner_text.replace(needle, 'moc_binary=""', 1)
else:
    raise SystemExit(f"unknown mutation: {mode}")

flake_path.write_text(flake_text, encoding="utf-8")
runner_path.write_text(runner_text, encoding="utf-8")
PY
}

for mode in \
    compiler \
    pkg-config \
    qt-core-moc \
    qt-qml \
    qml-consumer \
    dev-shell-consumer \
    path-moc; do
    reset_copy
    mutate "$mode"
    set +e
    bash "$repository_copy/tests/dependencies.sh" >/dev/null 2>&1
    status=$?
    set -e
    if [[ $status -eq 0 ]]; then
        printf 'FAIL: dependency validator accepted socket environment mutation %s\n' \
            "$mode" >&2
        exit 1
    fi
done

printf 'PASS: dependency validator rejects missing socket build inputs and PATH moc discovery\n'
