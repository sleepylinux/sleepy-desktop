#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
sdk_revision=5dc792faea9d743fabbb576ae1b25ed7e1f729f9
artwork_revision=108487617077254edb4e3a3b21047f5621eef151
session_revision=b88f5b993ae449acf176d8fc6f0d6542776d06bd
flake="$repository_root/flake.nix"
metadata_and_docs=("$flake" "$repository_root/README.md")

read_nix_block_attribute() {
  local block="$1"
  local attribute="$2"

  awk -v block="$block" -v attribute="$attribute" '
    $1 == block && $2 == "=" && $3 == "{" { in_block = 1; next }
    in_block && $1 == attribute && $2 == "=" {
      value = $3
      gsub(/[";]/, "", value)
      print value
      exit
    }
    in_block && $1 ~ /^}/ { exit }
  ' "$flake"
}

require_nix_block_attribute() {
  local block="$1"
  local attribute="$2"
  local expected="$3"
  local actual

  actual="$(read_nix_block_attribute "$block" "$attribute")"
  if [[ "$actual" != "$expected" ]]; then
    printf 'FAIL: %s.%s must be %s (got %s)\n' \
      "$block" "$attribute" "$expected" "${actual:-missing}" >&2
    exit 1
  fi
}

require_nix_block_attribute sleepy-sdk url "github:sleepylinux/sleepy-sdk/$sdk_revision"
require_nix_block_attribute sleepy-artwork url "github:sleepylinux/sleepy-artwork/$artwork_revision"
require_nix_block_attribute sleepy-session url "github:sleepylinux/sleepy-session/$session_revision"
require_nix_block_attribute passthru sdkRevision "$sdk_revision"
require_nix_block_attribute passthru artworkRevision "$artwork_revision"
require_nix_block_attribute passthru sessionRevision "$session_revision"

for revision in \
  4c4f7989b957f41f3748ddfb092b0348e2ba9e88 \
  7785ac5dac0daa6ac1a619f1e2a9a1b1d1374da1; do
  if rg -n -F "$revision" "${metadata_and_docs[@]}"; then
    printf 'FAIL: tracked dependency metadata/docs must not pin pre-GPL revision %s\n' \
      "$revision" >&2
    exit 1
  fi
done

rg -Fq "$sdk_revision" "$repository_root/README.md"
rg -Fq "$artwork_revision" "$repository_root/README.md"
rg -Fq "$session_revision" "$repository_root/README.md"

if ! rg -Fq 'sessionPackage = sleepy-session.packages.${system}.sleepy-session;' "$flake"; then
  printf 'FAIL: desktop package must consume the exact sleepy-session package\n' >&2
  exit 1
fi

if ! rg -Fq -- '--prefix PATH : "${sessionPackage}/bin"' "$flake"; then
  printf 'FAIL: packaged runners must expose pinned sleepyctl on PATH\n' >&2
  exit 1
fi

if ! rg -Fq 'sleepy-artwork.checks.${system}.assets' "$flake"; then
  printf 'FAIL: desktop checks must consume exact sleepy-artwork checks.<system>.assets\n' >&2
  exit 1
fi

if ! rg -Fq "export SLEEPY_ARTWORK_ROOT='\${artworkRoot}'" "$flake"; then
  printf 'FAIL: qml check must test the exact installed artwork root\n' >&2
  exit 1
fi

if ! rg -Fq -- '--set QML_XHR_ALLOW_FILE_READ 1' "$flake"; then
  printf 'FAIL: packaged QML runners must allow their pinned local manifest read\n' >&2
  exit 1
fi

if ! rg -Fq -- '--set QML2_IMPORT_PATH "${pkgs.qt6.qtdeclarative}/lib/qt-6/qml:${pkgs.quickshell}/lib/qt-6/qml"' "$flake"; then
  printf 'FAIL: packaged QML runners must close imports to the pinned Qt and Quickshell roots\n' >&2
  exit 1
fi
if rg -Fq -- '--prefix QML2_IMPORT_PATH' "$flake"; then
  printf 'FAIL: packaged QML runners must not retain caller-provided QML imports\n' >&2
  exit 1
fi
if ! rg -Fq -- '--set QML_IMPORT_PATH "${pkgs.qt6.qtdeclarative}/lib/qt-6/qml:${pkgs.quickshell}/lib/qt-6/qml"' "$flake"; then
  printf 'FAIL: packaged QML runners must close modern imports to the pinned Qt and Quickshell roots\n' >&2
  exit 1
fi
if rg -Fq -- '--prefix QML_IMPORT_PATH' "$flake"; then
  printf 'FAIL: packaged QML runners must not retain caller-provided modern QML imports\n' >&2
  exit 1
fi
if ! rg -Fq -- '--set QT_PLUGIN_PATH "${pkgs.qt6.qtsvg}/lib/qt-6/plugins:${pkgs.qt6.qtbase}/lib/qt-6/plugins"' "$flake"; then
  printf 'FAIL: packaged QML runners must expose only the pinned Qt SVG and base plugins\n' >&2
  exit 1
fi

qml_check_block="$(
  sed -n '/^          qml = pkgs.runCommand /,/^          package = pkgs.runCommand /p' "$flake"
)"
if ! rg -Fq 'bash "$repo_root/tests/dependencies.sh"' "$repository_root/tests/run.sh"; then
  printf 'FAIL: QML runner must invoke dependency checks through the pinned Bash on PATH\n' >&2
  exit 1
fi
if ! rg -Fq 'pkgs.glibc.bin' <<< "$qml_check_block"; then
  printf 'FAIL: qml check must provide glibc.bin so tests/run.sh can verify the generic Qt 6 runner with ldd\n' >&2
  exit 1
fi
if ! rg -Fq 'pkgs.qt6.qtsvg' <<< "$qml_check_block"; then
  printf 'FAIL: qml check must provide the Qt SVG image plugin used by icon fixtures\n' >&2
  exit 1
fi
if ! rg -Fq 'export PATH=${pkgs.qt6.qtdeclarative}/libexec:$PATH' <<< "$qml_check_block"; then
  printf 'FAIL: qml check must expose pinned Qt declarative libexec tools to static validation\n' >&2
  exit 1
fi
if ! rg -Fq 'export QT_PLUGIN_PATH=${pkgs.qt6.qtsvg}/lib/qt-6/plugins:${pkgs.qt6.qtbase}/lib/qt-6/plugins' \
    <<< "$qml_check_block"; then
  printf 'FAIL: qml check must expose its pinned Qt SVG and base plugin roots\n' >&2
  exit 1
fi
if ! rg -Fq 'pkgs.vulkan-loader' <<< "$qml_check_block" ||
    ! rg -Fq 'pkgs.xorg.xorgserver' <<< "$qml_check_block" ||
    ! rg -Fq 'Xvfb :99 -screen 0 1280x800x24' <<< "$qml_check_block" ||
    ! rg -Fq 'export SLEEPY_TEST_QPA_PLATFORM=xcb' <<< "$qml_check_block" ||
    ! rg -Fq 'export SLEEPY_TEST_RHI_BACKEND=vulkan' <<< "$qml_check_block" ||
    ! rg -Fq 'export VK_DRIVER_FILES=${pkgs.mesa}/share/vulkan/icd.d/lvp_icd.${pkgs.stdenv.hostPlatform.parsed.cpu.name}.json' <<< "$qml_check_block" ||
    ! rg -Fq 'export LD_LIBRARY_PATH=${pkgs.vulkan-loader}/lib' <<< "$qml_check_block" ||
    ! rg -Fq 'QSG_RHI_BACKEND="${SLEEPY_TEST_RHI_BACKEND:-opengl}"' "$repository_root/tests/run.sh"; then
  printf 'FAIL: qml check must provide Xvfb/xcb and pinned Mesa lavapipe for its configurable real RHI smoke\n' >&2
  exit 1
fi
if rg -Fq 'lvp_icd.x86_64.json' <<< "$qml_check_block"; then
  printf 'FAIL: qml check must not hard-code an x86-only Mesa lavapipe ICD filename\n' >&2
  exit 1
fi
if ! rg -Fq 'export QML2_IMPORT_PATH=${pkgs.qt6.qtdeclarative}/lib/qt-6/qml:${pkgs.quickshell}/lib/qt-6/qml' \
    <<< "$qml_check_block"; then
  printf 'FAIL: qml check must expose its pinned Qt and Quickshell QML module roots\n' >&2
  exit 1
fi
if ! rg -Fq 'export SLEEPY_QUICKSHELL_IMPORT_PATH=${pkgs.quickshell}/lib/qt-6/qml' \
    <<< "$qml_check_block"; then
  printf 'FAIL: static validation must receive the exact pinned Quickshell QML root\n' >&2
  exit 1
fi

preview_check_block="$(
  sed -n '/^          preview = pkgs.runCommand /,/^        });$/p' "$flake"
)"
if ! rg -Fq 'timeout 3 "$preview_package/bin/sleepy-settings-preview"' <<< "$preview_check_block" ||
    ! rg -Fq '[[ $preview_status -ne 124 ]]' <<< "$preview_check_block"; then
  printf 'FAIL: packaged preview check must preserve the timeout-alive assertion\n' >&2
  exit 1
fi
if ! rg -Fq "grep -Fq 'Unsupported image format'" <<< "$preview_check_block" ||
    ! rg -Fq "grep -Fq 'QML Image:'" <<< "$preview_check_block"; then
  printf 'FAIL: packaged preview check must reject every SVG/image decoding error\n' >&2
  exit 1
fi

checks_attrset="$(
  sed -n '/^      checks = forAllSystems (system:/,/^        });$/p' "$flake" |
    sed -n '/^        {$/,/^        });$/p'
)"
mapfile -t check_names < <(
  sed -nE \
    -e 's/^          ([A-Za-z_][A-Za-z0-9_-]*)[[:space:]]*=.*/\1/p' \
    -e 's/^          "([^"]+)"[[:space:]]*=.*/\1/p' \
    <<< "$checks_attrset"
)
if [[ "${check_names[*]:-}" != "qml package preview" ]]; then
  printf 'FAIL: per-system desktop checks must expose exactly qml package preview, found: %s\n' \
    "${check_names[*]:-(none)}" >&2
  exit 1
fi

printf 'PASS: desktop dependency metadata pins reviewed GPL revisions\n'
