#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$repo_root/tests/lib/parity-validator.sh"
evidence_registry="$repo_root/tests/parity-evidence-registry.json"
parity_manifest="$repo_root/tests/parity-manifest.json"
evidence_scratch="$(mktemp -d)"
trap 'rm -rf -- "$evidence_scratch"' EXIT
evidence_results="$evidence_scratch/results.txt"
: >"$evidence_results"

bash "$repo_root/tests/upstream-provenance.sh"
bash "$repo_root/tests/patch-inventory-validator-test.sh"
bash "$repo_root/tests/patch-inventory.sh"
bash "$repo_root/tests/dependencies.sh"
bash "$repo_root/tests/socket-contract-environment-validator-test.sh"
bash "$repo_root/tests/qt6-moc-resolver-test.sh"
bash "$repo_root/tests/artwork-manifest.sh"
bash "$repo_root/tests/motion-contracts.sh"
bash "$repo_root/tests/ipc-contracts.sh"
bash "$repo_root/tests/m3-contracts.sh"
bash "$repo_root/tests/command-builders.sh"
bash "$repo_root/tests/direct-integrations.sh"
bash "$repo_root/tests/desktop-command-corpus.sh"
bash "$repo_root/tests/quickshell-core-host-contract.sh"
bash "$repo_root/tests/private-wayland-contract.sh"
bash "$repo_root/tests/private-wayland-supervisor-contract.sh"
bash "$repo_root/tests/nix-qml-environment-contract.sh"
bash "$repo_root/tests/quickshell-pin-validator-test.sh"
bash "$repo_root/tests/runtime-names.sh"
bash "$repo_root/tests/closed-imports.sh"
bash "$repo_root/tests/closed-imports-validator-test.sh"
bash "$repo_root/tests/qml-inline-id-contract.sh"
bash "$repo_root/tests/qml-inline-id-validator-test.sh"
bash "$repo_root/tests/desktop-client-load.sh"
bash "$repo_root/tests/desktop-client-socket-contract.sh"
bash "$repo_root/tests/service-boundary.sh"
bash "$repo_root/tests/shell-ipc-wrapper.sh"
run_parity_shell_evidence "$evidence_registry" "$repo_root" "$evidence_results"
bash "$repo_root/tests/parity-validator-test.sh"
bash "$repo_root/tests/parity.sh"

if [[ -x /usr/lib/qt6/bin/qmltestrunner ]]; then
  qml_test_runner=/usr/lib/qt6/bin/qmltestrunner
elif command -v qmltestrunner-qt6 >/dev/null 2>&1; then
  qml_test_runner="$(command -v qmltestrunner-qt6)"
elif command -v qmltestrunner >/dev/null 2>&1 \
    && ldd "$(command -v qmltestrunner)" 2>/dev/null | grep -q 'libQt6'; then
  qml_test_runner="$(command -v qmltestrunner)"
else
  printf 'FAIL: qmltestrunner is required for runnable QML behavior tests\n' >&2
  exit 1
fi

# QML behavior tests are headless.  Never let them inherit the caller's live
# Wayland socket or desktop theme: both turn an offscreen test into a session-
# coupled process and can leave Qt's crash handler waiting for a GUI.
unset WAYLAND_DISPLAY WAYLAND_SOCKET HYPRLAND_INSTANCE_SIGNATURE SWAYSOCK I3SOCK
unset QT_QPA_PLATFORMTHEME KDE_FULL_SESSION XDG_CURRENT_DESKTOP
export KDE_DEBUG=1
export QT_STYLE_OVERRIDE=Fusion
export QT_QPA_PLATFORM=offscreen
export QT_QUICK_BACKEND="${SLEEPY_TEST_QUICK_BACKEND:-software}"
export QML_XHR_ALLOW_FILE_READ=1
export QML2_IMPORT_PATH="$repo_root/src${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
qml_timeout_seconds="${SLEEPY_QML_TIMEOUT_SECONDS:-120}"
if [[ ! "$qml_timeout_seconds" =~ ^[1-9][0-9]*$ ]]; then
  printf 'FAIL: SLEEPY_QML_TIMEOUT_SECONDS must be a positive integer\n' >&2
  exit 1
fi

timeout --signal=TERM --kill-after=5s "$qml_timeout_seconds" \
  "$qml_test_runner" -input "$repo_root/tests/qml" -import "$repo_root/src" -v1 \
  2>&1 | tee "$evidence_scratch/qml-software.log"
record_parity_qml_evidence "$parity_manifest" \
  "$evidence_scratch/qml-software.log" "$evidence_results"

# Qt Quick's painter-style software backend intentionally does not execute
# Re-run real production surfaces and the icon mask path with the RHI
# scenegraph and Mesa software rendering. Each runner remains independently
# bounded so a driver or scenegraph hang cannot be hidden.
for rhi_test in tst_icons.qml tst_m3_gallery.qml tst_m3_surfaces.qml tst_core_surfaces.qml tst_core_overlays.qml tst_parity.qml; do
  QT_QUICK_BACKEND=rhi \
  QSG_RHI_BACKEND="${SLEEPY_TEST_RHI_BACKEND:-opengl}" \
  LIBGL_ALWAYS_SOFTWARE=1 \
  timeout --signal=TERM --kill-after=5s "$qml_timeout_seconds" \
    "$qml_test_runner" \
    -input "$repo_root/tests/qml/$rhi_test" \
    -import "$repo_root/src" \
    -v1
done

validate_parity_evidence_results "$parity_manifest" "$evidence_results"

private_compositor="${SLEEPY_TEST_WAYLAND_COMPOSITOR:-${SLEEPY_TEST_SWAY:-}}"
SLEEPY_TEST_QUICKSHELL="${SLEEPY_TEST_QUICKSHELL:-}"
if [[ -n "$private_compositor" && -x "$private_compositor" ]]; then
  bash "$repo_root/tests/with-private-wayland.sh" \
    "$repo_root/tests/quickshell-core-host.sh" software "$SLEEPY_TEST_QUICKSHELL"
  bash "$repo_root/tests/with-private-wayland.sh" \
    "$repo_root/tests/quickshell-core-host.sh" rhi "$SLEEPY_TEST_QUICKSHELL"
else
  printf 'SKIP: private Wayland compositor is not configured; real Quickshell host gate was not run\n'
fi
