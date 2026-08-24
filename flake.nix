{
  description = "Sleepy Quickshell desktop material and generic-surface foundation";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    sleepy-sdk = {
      url = "github:sleepylinux/sleepy-sdk/5dc792faea9d743fabbb576ae1b25ed7e1f729f9";
      flake = false;
    };

    sleepy-artwork = {
      url = "github:sleepylinux/sleepy-artwork/108487617077254edb4e3a3b21047f5621eef151";
    };

    sleepy-session = {
      url = "github:sleepylinux/sleepy-session/818e19f242bf4d67adbf1c2294ad2557e915a458";
    };
  };

  outputs = { self, nixpkgs, sleepy-sdk, sleepy-artwork, sleepy-session }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      packagesFor = system:
        let
          pkgs = import nixpkgs { inherit system; };
          installRoot = "share/sleepy-desktop";
          artworkPackage = sleepy-artwork.packages.${system}.sleepy-artwork;
          sessionPackage = sleepy-session.packages.${system}.sleepy-session;
          artworkRoot = "${artworkPackage}/share/sleepy-artwork";
          artworkManifest = "${artworkRoot}/branding/manifest.json";

          mkDesktopPackage = { pname, runner, runnerFlags }:
            pkgs.stdenvNoCC.mkDerivation {
              inherit pname;
              version = "0.2.0";
              src = self;
              nativeBuildInputs = [ pkgs.jq pkgs.makeWrapper ];
              dontBuild = true;

              installPhase = ''
                runHook preInstall

                mkdir -p "$out/${installRoot}" "$out/bin" "$out/${installRoot}/contracts"
                cp -R src/. "$out/${installRoot}/"
                install -Dm644 \
                  "${sleepy-sdk}/schemas/settings.schema.json" \
                  "$out/${installRoot}/contracts/settings.schema.json"
                install -Dm644 \
                  "${sleepy-sdk}/schemas/system.schema.json" \
                  "$out/${installRoot}/contracts/system.schema.json"
                install -Dm644 \
                  "${sleepy-sdk}/schemas/preset.schema.json" \
                  "$out/${installRoot}/contracts/preset.schema.json"

                test "$(jq -er '.version' '${artworkManifest}')" = 1
                primary_mark_relative="$(jq -er '.assets["branding.primaryMark"]' '${artworkManifest}')"
                case "$primary_mark_relative" in
                  /*|*..*)
                    printf 'branding.primaryMark must be a package-relative manifest path\n' >&2
                    exit 1
                    ;;
                esac
                primary_mark="${artworkRoot}/$primary_mark_relative"
                if [[ ! -f "$primary_mark" ]]; then
                  printf 'branding.primaryMark is missing: %s\n' "$primary_mark" >&2
                  exit 1
                fi

                while IFS= read -r qml_file; do
                  substituteInPlace "$qml_file" \
                    --replace-fail '@sleepyPrimaryMark@' "$primary_mark"
                done < <(grep -rl '@sleepyPrimaryMark@' "$out/${installRoot}")
                while IFS= read -r qml_file; do
                  substituteInPlace "$qml_file" \
                    --replace-fail '@sleepyArtworkRoot@' '${artworkRoot}'
                done < <(grep -rl '@sleepyArtworkRoot@' "$out/${installRoot}")
                while IFS= read -r qml_file; do
                  substituteInPlace "$qml_file" \
                    --replace-fail '@sleepyArtworkManifest@' '${artworkManifest}'
                done < <(grep -rl '@sleepyArtworkManifest@' "$out/${installRoot}")

                if grep -R '@sleepy' "$out/${installRoot}"; then
                  printf 'unresolved Sleepy package placeholder\n' >&2
                  exit 1
                fi

                makeWrapper "${runner}" "$out/bin/${pname}" \
                  --set QML_XHR_ALLOW_FILE_READ 1 \
                  --prefix PATH : "${sessionPackage}/bin" \
                  --add-flags "${runnerFlags "$out/${installRoot}"}"

                runHook postInstall
              '';

              passthru = {
                sdkRevision = "5dc792faea9d743fabbb576ae1b25ed7e1f729f9";
                artworkRevision = "108487617077254edb4e3a3b21047f5621eef151";
                sessionRevision = "818e19f242bf4d67adbf1c2294ad2557e915a458";
                inherit artworkRoot artworkManifest;
              };

              meta = {
                description = "Sleepy cozy-night Quickshell desktop foundation";
                license = pkgs.lib.licenses.gpl3Only;
                platforms = pkgs.lib.platforms.linux;
              };
            };
        in
        rec {
          sleepy-shell = mkDesktopPackage {
            pname = "sleepy-shell";
            runner = "${pkgs.quickshell}/bin/qs";
            runnerFlags = installPath: "-p ${installPath}/shell.qml";
          };

          sleepy-settings-preview = mkDesktopPackage {
            pname = "sleepy-settings-preview";
            runner = "${pkgs.qt6.qtdeclarative}/bin/qml";
            runnerFlags = installPath: "-I ${installPath} ${installPath}/preview/main.qml";
          };

          default = sleepy-shell;
        };
    in
    {
      packages = forAllSystems packagesFor;

      checks = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          componentPackages = packagesFor system;
          artworkPackage = sleepy-artwork.packages.${system}.sleepy-artwork;
          sessionPackage = sleepy-session.packages.${system}.sleepy-session;
          artworkRoot = "${artworkPackage}/share/sleepy-artwork";
          artworkManifest = "${artworkRoot}/branding/manifest.json";
        in
        {
          qml = pkgs.runCommand "sleepy-desktop-qml-contracts" {
            artworkAssets = sleepy-artwork.checks.${system}.assets;
            nativeBuildInputs = [
              pkgs.bash
              pkgs.coreutils
              pkgs.glibc.bin
              pkgs.jq
              pkgs.quickshell
              pkgs.ripgrep
              pkgs.qt6.qtbase
              pkgs.qt6.qtdeclarative
              pkgs.qt6.qtsvg
              pkgs.vulkan-loader
              pkgs.xorg.xorgserver
            ];
          } ''
            cd ${self}
            Xvfb :99 -screen 0 1280x800x24 >/tmp/sleepy-xvfb.log 2>&1 &
            xvfb_pid=$!
            trap 'kill "$xvfb_pid" 2>/dev/null || true' EXIT
            for _ in $(seq 1 50); do
              [[ -S /tmp/.X11-unix/X99 ]] && break
              sleep 0.1
            done
            test -S /tmp/.X11-unix/X99
            export DISPLAY=:99
            export SLEEPY_TEST_QPA_PLATFORM=xcb
            export QT_QUICK_BACKEND=software
            export QT_PLUGIN_PATH=${pkgs.qt6.qtsvg}/lib/qt-6/plugins:${pkgs.qt6.qtbase}/lib/qt-6/plugins
            export LIBGL_DRIVERS_PATH=${pkgs.mesa}/lib/dri
            export SLEEPY_TEST_RHI_BACKEND=vulkan
            export VK_DRIVER_FILES=${pkgs.mesa}/share/vulkan/icd.d/lvp_icd.${pkgs.stdenv.hostPlatform.parsed.cpu.name}.json
            export LD_LIBRARY_PATH=${pkgs.vulkan-loader}/lib
            export QML2_IMPORT_PATH=${pkgs.qt6.qtdeclarative}/lib/qt-6/qml:${pkgs.quickshell}/lib/qt-6/qml
            export SLEEPY_QUICKSHELL_IMPORT_PATH=${pkgs.quickshell}/lib/qt-6/qml
            export PATH=${pkgs.qt6.qtdeclarative}/libexec:$PATH
            export SLEEPY_ARTWORK_ROOT='${artworkRoot}'
            bash tests/run.sh
            bash scripts/validate-qml.sh
            test -e "$artworkAssets"
            touch "$out"
          '';

          package = pkgs.runCommand "sleepy-desktop-package-contracts" {
            nativeBuildInputs = [ pkgs.jq pkgs.ripgrep ];
          } ''
            shell_package=${componentPackages.sleepy-shell}
            test -x "$shell_package/bin/sleepy-shell"
            test -f "$shell_package/share/sleepy-desktop/services/IconRegistry.qml"
            test -f '${artworkManifest}'
            test "$(jq -er '.version' '${artworkManifest}')" = 1
            rg -F '${artworkRoot}' \
              "$shell_package/share/sleepy-desktop/services/IconRegistry.qml"
            rg -F '${artworkManifest}' \
              "$shell_package/share/sleepy-desktop/services/IconRegistry.qml"
            rg -F '${sessionPackage}/bin' "$shell_package/bin/sleepy-shell"
            if rg '@sleepy[A-Za-z]+@' "$shell_package/share/sleepy-desktop"; then
              exit 1
            fi
            touch "$out"
          '';

          preview = pkgs.runCommand "sleepy-desktop-preview-contracts" {
            nativeBuildInputs = [ pkgs.coreutils ];
          } ''
            preview_package=${componentPackages.sleepy-settings-preview}
            test -x "$preview_package/bin/sleepy-settings-preview"
            set +e
            QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
              timeout 3 "$preview_package/bin/sleepy-settings-preview"
            preview_status=$?
            set -e
            if [[ $preview_status -ne 124 ]]; then
              printf 'packaged preview exited unexpectedly with status %s\n' "$preview_status" >&2
              exit 1
            fi
            touch "$out"
          '';
        });
    };
}
