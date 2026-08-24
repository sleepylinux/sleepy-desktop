{
  description = "Sleepy Quickshell desktop material and generic-surface foundation";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    sleepy-sdk = {
      url = "github:sleepylinux/sleepy-sdk/2edbe8310eee69c40e4f75924da67a57942bd1c3";
      flake = false;
    };

    sleepy-artwork = {
      url = "github:sleepylinux/sleepy-artwork/bd0d9ac2261b4dc2c3ad41e6d3d898b22cda2a85";
    };
  };

  outputs = { self, nixpkgs, sleepy-sdk, sleepy-artwork }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      packagesFor = system:
        let
          pkgs = import nixpkgs { inherit system; };
          installRoot = "share/sleepy-desktop";
          artworkPackage = sleepy-artwork.packages.${system}.sleepy-artwork;
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
                  --add-flags "${runnerFlags "$out/${installRoot}"}"

                runHook postInstall
              '';

              passthru = {
                sdkRevision = "2edbe8310eee69c40e4f75924da67a57942bd1c3";
                artworkRevision = "bd0d9ac2261b4dc2c3ad41e6d3d898b22cda2a85";
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
          artworkRoot = "${artworkPackage}/share/sleepy-artwork";
          artworkManifest = "${artworkRoot}/branding/manifest.json";
        in
        {
          qml = pkgs.runCommand "sleepy-desktop-qml-contracts" {
            artworkAssets = sleepy-artwork.checks.${system}.assets;
            nativeBuildInputs = [
              pkgs.bash
              pkgs.coreutils
              pkgs.jq
              pkgs.quickshell
              pkgs.ripgrep
              pkgs.qt6.qtbase
              pkgs.qt6.qtdeclarative
            ];
          } ''
            cd ${self}
            export QT_QPA_PLATFORM=offscreen
            export QT_QUICK_BACKEND=software
            export LIBGL_DRIVERS_PATH=${pkgs.mesa}/lib/dri
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
