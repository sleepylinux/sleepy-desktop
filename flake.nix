{
  description = "Sleepy Quickshell desktop material and generic-surface foundation";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    sleepy-sdk = {
      url = "github:sleepylinux/sleepy-sdk/63b2370a39f47f2b361310c12c0333da0faaee9d";
      flake = false;
    };

    sleepy-artwork = {
      url = "github:sleepylinux/sleepy-artwork/175314b9c236c1b412e8e1ebc54bbe3937b0c90d";
    };

    sleepy-session = {
      url = "github:sleepylinux/sleepy-session/07fa0e3d20c7a39293023c75408782447a6520fc";
    };

    quickshell = {
      url = "git+https://git.outfoxxed.me/outfoxxed/quickshell?rev=0fed22a2c47d9568ddf13cf61586b3f2ac4378a2";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    m3shapes = {
      url = "github:soramanew/m3shapes/32ad9ce328bb77ed349b40a3be10ee9ea610b8ab";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, sleepy-sdk, sleepy-artwork, sleepy-session, quickshell, m3shapes }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      socketContractNativeInputs = pkgs: [
        pkgs.stdenv.cc
        pkgs.pkg-config
        pkgs.qt6.qtbase
        pkgs.qt6.qtdeclarative
      ];

      packagesFor = system:
        let
          pkgs = import nixpkgs { inherit system; };
          installRoot = "share/sleepy-desktop";
          artworkPackage = sleepy-artwork.packages.${system}.sleepy-artwork;
          sessionPackage = sleepy-session.packages.${system}.sleepy-session;
          artworkRoot = "${artworkPackage}/share/sleepy-artwork";
          artworkManifest = "${artworkRoot}/branding/manifest.json";
          quickshellPackage = quickshell.packages.${system}.default.override {
            withX11 = false;
            withI3 = false;
          };
          m3shapesPackage = m3shapes.packages.${system}.default;
          quickshellWithModules = quickshellPackage.withModules [ pkgs.qt6.qtimageformats m3shapesPackage ];
          runtimeCommandPackages = {
            hyprctl = pkgs.hyprland;
            xmllint = pkgs.libxml2;
            nmcli = pkgs.networkmanager;
            cat = pkgs.coreutils;
            brightnessctl = pkgs.brightnessctl;
            ddcutil = pkgs.ddcutil;
            notify-send = pkgs.libnotify;
            swappy = pkgs.swappy;
            sleepy = appearanceCli;
            ping = pkgs.iputils;
            ip = pkgs.iproute2;
            pkexec = pkgs.polkit;
            wg-quick = pkgs.wireguard-tools;
            ghostty = pkgs.ghostty;
          }
          // pkgs.lib.optionalAttrs (pkgs ? asdbctl) { asdbctl = pkgs.asdbctl; }
          // pkgs.lib.optionalAttrs (pkgs ? netbird) { netbird = pkgs.netbird; }
          // pkgs.lib.optionalAttrs (pkgs ? tailscale) { tailscale = pkgs.tailscale; };
          directRuntimePackages = pkgs.lib.unique (
            builtins.attrValues runtimeCommandPackages ++ [
              sessionPackage
              pkgs.bluez
              pkgs.wireplumber
              pkgs.pipewire
              pkgs.power-profiles-daemon
              pkgs.upower
              pkgs.wl-clipboard
              pkgs.libqalculate
              pkgs.lm_sensors
            ]
          );
          directRuntimePath = pkgs.lib.makeBinPath directRuntimePackages;
          runtimeCommandManifest = pkgs.writeText "sleepy-runtime-command-paths.json" (
            builtins.toJSON (pkgs.lib.mapAttrs
              (command: package: "${package}/bin/${command}")
              runtimeCommandPackages)
          );
          fontconfig = pkgs.makeFontsConf {
            fontDirectories = [
              pkgs.material-symbols
              pkgs.rubik
              pkgs.nerd-fonts.caskaydia-cove
            ];
          };
          appearanceCli = pkgs.python3Packages.buildPythonApplication {
            pname = "sleepy-appearance-cli";
            version = "0.2.0";
            src = ./appearance-cli;
            pyproject = true;
            build-system = [ pkgs.python3Packages.hatchling ];
            dependencies = with pkgs.python3Packages; [ pillow materialyoucolor ];
            pythonImportsCheck = [ "sleepy" ];
            postInstall = ''
              install -Dm644 LICENSE "$out/share/doc/sleepy-appearance-cli/LICENSE"
              install -Dm644 UPSTREAM.json "$out/share/doc/sleepy-appearance-cli/UPSTREAM.json"
            '';
            meta = {
              description = "Modular Sleepy scheme, wallpaper, and shell IPC helper";
              license = pkgs.lib.licenses.gpl3Only;
              mainProgram = "sleepy";
              platforms = pkgs.lib.platforms.linux;
            };
          };
          nativePlugin = pkgs.clangStdenv.mkDerivation {
            pname = "sleepy-qml-plugin";
            version = "0.2.0";
            src = pkgs.lib.fileset.toSource {
              root = ./src;
              fileset = pkgs.lib.fileset.unions [
                ./src/CMakeLists.txt
                ./src/plugin
              ];
            };
            nativeBuildInputs = [
              pkgs.cmake
              pkgs.ninja
              pkgs.pkg-config
            ];
            buildInputs = [
              pkgs.aubio
              pkgs.fftw
              pkgs.pipewire
              pkgs.libcava
              pkgs.lm_sensors
              pkgs.libqalculate
              pkgs.qt6.qtbase
              pkgs.qt6.qtdeclarative
              pkgs.qt6.qtimageformats
              pkgs.qt6.qtshadertools
            ];
            dontWrapQtApps = true;
            cmakeFlags = [
              (pkgs.lib.cmakeFeature "ENABLE_MODULES" "plugin")
              (pkgs.lib.cmakeFeature "INSTALL_QMLDIR" pkgs.qt6.qtbase.qtQmlPrefix)
              (pkgs.lib.cmakeFeature "VERSION" "0.2.0")
              (pkgs.lib.cmakeFeature "GIT_REVISION" (self.rev or self.dirtyRev or "dirty"))
              (pkgs.lib.cmakeFeature "DISTRIBUTOR" "sleepy-nix-flake")
            ];
          };
          lockerPackage = pkgs.clangStdenv.mkDerivation {
            pname = "sleepy-locker";
            version = "0.2.0";
            src = pkgs.lib.fileset.toSource {
              root = ./.;
              fileset = pkgs.lib.fileset.unions [
                ./locker
                ./tests/locker_native.cpp
              ];
            };
            cmakeDir = "../locker";
            nativeBuildInputs = [
              pkgs.cmake
              pkgs.makeWrapper
              pkgs.ninja
              pkgs.pkg-config
            ];
            buildInputs = [
              pkgs.pam
              pkgs.qt6.qtbase
              pkgs.qt6.qtdeclarative
            ];
            runner = "${quickshellWithModules}/bin/qs";
            dontWrapQtApps = true;
            doCheck = true;
            checkPhase = ''
              runHook preCheck
              QT_QPA_PLATFORM=offscreen \
              QT_QUICK_BACKEND=software \
              QT_QPA_PLATFORMTHEME= \
              KDE_FULL_SESSION= \
              XDG_CURRENT_DESKTOP= \
                ctest --test-dir . --output-on-failure
              runHook postCheck
            '';
            postInstall = ''
              makeWrapper "$out/libexec/sleepy-locker/sleepy-locker-supervisor" "$out/bin/sleepy-locker" \
                --set QML2_IMPORT_PATH "$out/lib/qt6/qml:${quickshellWithModules}/lib/qt-6/qml" \
                --set QML_IMPORT_PATH "$out/lib/qt6/qml:${quickshellWithModules}/lib/qt-6/qml" \
                --add-flags "${quickshellWithModules}/bin/qs" \
                --add-flags "-p" \
                --add-flags "$out/share/sleepy-locker/LockRoot.qml"
            '';
            meta = {
              description = "Fail-secure Sleepy ext-session-lock-v1 locker";
              license = pkgs.lib.licenses.gpl3Only;
              platforms = pkgs.lib.platforms.linux;
              mainProgram = "sleepy-locker";
            };
          };
          qtQmlImportPath = "${pkgs.qt6.qtdeclarative}/lib/qt-6/qml:${quickshellWithModules}/lib/qt-6/qml:${nativePlugin}/${pkgs.qt6.qtbase.qtQmlPrefix}";

          mkDesktopPackage = { pname, runner, runnerFlags, withIpcClient ? false }:
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
                rm -rf "$out/${installRoot}/modules/lock" "$out/${installRoot}/assets/pam.d"
                install -Dm644 NOTICE "$out/share/doc/sleepy-desktop/NOTICE"
                if [[ -f src/LICENSE ]]; then
                  install -Dm644 src/LICENSE "$out/share/doc/sleepy-desktop/LICENSE"
                fi
                install -Dm644 \
                  "${sleepy-sdk}/schemas/settings.schema.json" \
                  "$out/${installRoot}/contracts/settings.schema.json"
                install -Dm644 \
                  "${sleepy-sdk}/schemas/system.schema.json" \
                  "$out/${installRoot}/contracts/system.schema.json"
                install -Dm644 \
                  "${sleepy-sdk}/schemas/preset.schema.json" \
                  "$out/${installRoot}/contracts/preset.schema.json"
                install -Dm644 \
                  "${sleepy-sdk}/schemas/desktop-event-v3.schema.json" \
                  "$out/${installRoot}/contracts/desktop-event-v3.schema.json"
                install -Dm644 \
                  "${sleepy-sdk}/schemas/desktop-command-v3.schema.json" \
                  "$out/${installRoot}/contracts/desktop-command-v3.schema.json"
                install -Dm644 tests/direct-integrations.json \
                  "$out/${installRoot}/direct-integrations.json"
                install -Dm644 "${runtimeCommandManifest}" \
                  "$out/${installRoot}/runtime-command-paths.json"

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
                  --set QML2_IMPORT_PATH "${qtQmlImportPath}" \
                  --set QML_IMPORT_PATH "${qtQmlImportPath}" \
                  --set QT_PLUGIN_PATH "${pkgs.qt6.qtsvg}/lib/qt-6/plugins:${pkgs.qt6.qtbase}/lib/qt-6/plugins" \
                  --set FONTCONFIG_FILE "${fontconfig}" \
                  --set SLEEPY_XKB_RULES_PATH "${pkgs.xkeyboard-config}/share/xkeyboard-config-2/rules/base.lst" \
                  --prefix PATH : "${directRuntimePath}" \
                  --add-flags "${runnerFlags "$out/${installRoot}"}"

                ${pkgs.lib.optionalString withIpcClient ''
                  makeWrapper "${quickshellWithModules}/bin/qs" "$out/bin/sleepy-shell-ipc" \
                    --set QML_XHR_ALLOW_FILE_READ 1 \
                    --set QML2_IMPORT_PATH "${qtQmlImportPath}" \
                    --set QML_IMPORT_PATH "${qtQmlImportPath}" \
                    --set QT_PLUGIN_PATH "${pkgs.qt6.qtsvg}/lib/qt-6/plugins:${pkgs.qt6.qtbase}/lib/qt-6/plugins" \
                    --add-flags "ipc --path $out/${installRoot}/shell.qml"
                ''}

                runHook postInstall
              '';

              passthru = {
                sdkRevision = "63b2370a39f47f2b361310c12c0333da0faaee9d";
                artworkRevision = "175314b9c236c1b412e8e1ebc54bbe3937b0c90d";
                sessionRevision = "07fa0e3d20c7a39293023c75408782447a6520fc";
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
          sleepy-qml-plugin = nativePlugin;
          sleepy-locker = lockerPackage;
          sleepy-appearance-cli = appearanceCli;

          sleepy-shell = mkDesktopPackage {
            pname = "sleepy-shell";
            runner = "${quickshellWithModules}/bin/qs";
            runnerFlags = installPath: "-p ${installPath}/shell.qml";
            withIpcClient = true;
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

      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = socketContractNativeInputs pkgs;
          };
        });

      checks = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          componentPackages = packagesFor system;
          artworkPackage = sleepy-artwork.packages.${system}.sleepy-artwork;
          sessionPackage = sleepy-session.packages.${system}.sleepy-session;
          artworkRoot = "${artworkPackage}/share/sleepy-artwork";
          artworkManifest = "${artworkRoot}/branding/manifest.json";
          quickshellPackage = quickshell.packages.${system}.default.override {
            withX11 = false;
            withI3 = false;
          };
          m3shapesPackage = m3shapes.packages.${system}.default;
          quickshellWithModules = quickshellPackage.withModules [ pkgs.qt6.qtimageformats m3shapesPackage ];
          nativePlugin = componentPackages.sleepy-qml-plugin;
          qtQmlImportPath = "${pkgs.qt6.qtdeclarative}/lib/qt-6/qml:${quickshellWithModules}/lib/qt-6/qml:${nativePlugin}/${pkgs.qt6.qtbase.qtQmlPrefix}";
        in
        {
          locker = componentPackages.sleepy-locker;

          qml = pkgs.runCommand "sleepy-desktop-qml-contracts" {
            artworkAssets = sleepy-artwork.checks.${system}.assets;
            nativeBuildInputs = [
              pkgs.bash
              pkgs.coreutils
              pkgs.dbus
              pkgs.glibc.bin
              pkgs.jq
              pkgs.procps
              pkgs.python3
              pkgs.util-linux
              quickshellWithModules
              pkgs.ripgrep
              pkgs.qt6.qtsvg
              pkgs.vulkan-loader
              pkgs.sway
              pkgs.xorg.xorgserver
            ] ++ socketContractNativeInputs pkgs;
          } ''
            cd ${self}
            display_number=100
            while [[ -e /tmp/.X''${display_number}-lock \
                || -S /tmp/.X11-unix/X''${display_number} ]]; do
              display_number=$((display_number + 1))
            done
            Xvfb ":$display_number" -screen 0 1280x800x24 \
              >"$TMPDIR/sleepy-xvfb.log" 2>&1 &
            xvfb_pid=$!
            cleanup_xvfb() {
              kill "$xvfb_pid" 2>/dev/null || true
              wait "$xvfb_pid" 2>/dev/null || true
            }
            trap cleanup_xvfb EXIT
            for _ in $(seq 1 50); do
              [[ -S "/tmp/.X11-unix/X$display_number" ]] && break
              sleep 0.1
            done
            test -S "/tmp/.X11-unix/X$display_number"
            export DISPLAY=":$display_number"
            export SLEEPY_TEST_QPA_PLATFORM=xcb
            export SLEEPY_QML_TIMEOUT_SECONDS=120
            export SLEEPY_PRIVATE_WAYLAND_TIMEOUT_SECONDS=600
            export QT_QUICK_BACKEND=software
            export QT_PLUGIN_PATH=${pkgs.qt6.qtsvg}/lib/qt-6/plugins:${pkgs.qt6.qtbase}/lib/qt-6/plugins
            export LIBGL_DRIVERS_PATH=${pkgs.mesa}/lib/dri
            export SLEEPY_TEST_RHI_BACKEND=vulkan
            export VK_DRIVER_FILES=${pkgs.mesa}/share/vulkan/icd.d/lvp_icd.${pkgs.stdenv.hostPlatform.parsed.cpu.name}.json
            export LD_LIBRARY_PATH=${pkgs.vulkan-loader}/lib
            export QML2_IMPORT_PATH=${qtQmlImportPath}
            export QML_IMPORT_PATH=${qtQmlImportPath}
            export SLEEPY_QUICKSHELL_IMPORT_PATH=${quickshellWithModules}/lib/qt-6/qml
            readonly SLEEPY_TEST_QUICKSHELL=${quickshellWithModules}/bin/qs
            export SLEEPY_TEST_QUICKSHELL
            export PATH=${pkgs.qt6.qtdeclarative}/libexec:$PATH
            export SLEEPY_ARTWORK_ROOT='${artworkRoot}'
            export SLEEPY_SDK_ROOT='${sleepy-sdk}'
            export SLEEPY_TEST_SWAY=${pkgs.sway}/bin/sway
            export SLEEPY_TEST_WAYLAND_COMPOSITOR=${pkgs.sway}/bin/sway
            export SLEEPY_APPEARANCE_CLI=${componentPackages.sleepy-appearance-cli}/bin/sleepy
            test -d "${nativePlugin}/${pkgs.qt6.qtbase.qtQmlPrefix}/Sleepy"
            unset WAYLAND_DISPLAY
            bash tests/run.sh
            ${pkgs.qt6.qtdeclarative}/libexec/qmltestrunner \
              -input tests/qml-native/tst_native_full_plugin.qml \
              -import ${nativePlugin}/${pkgs.qt6.qtbase.qtQmlPrefix} -v1
            SLEEPY_NATIVE_QML_IMPORT_PATH=${nativePlugin}/${pkgs.qt6.qtbase.qtQmlPrefix} \
              bash tests/full-settings-contract.sh
            bash scripts/validate-qml.sh

            production_shell=${componentPackages.sleepy-shell}
            bash tests/with-private-wayland.sh \
              bash tests/packaged-shell-smoke.sh \
                "$production_shell/bin/sleepy-shell"
            bash tests/with-private-wayland.sh \
              bash tests/packaged-full-shell-smoke.sh \
                "$production_shell/bin/sleepy-shell" \
                "$production_shell/${installRoot}/runtime-command-paths.json"

            production_locker=${componentPackages.sleepy-locker}
            bash tests/with-private-wayland.sh \
              bash tests/packaged-locker-smoke.sh \
                "$production_locker/bin/sleepy-locker"

            test -e "$artworkAssets"
            touch "$out"
          '';

          package = pkgs.runCommand "sleepy-desktop-package-contracts" {
            nativeBuildInputs = [
              pkgs.bash
              pkgs.coreutils
              pkgs.jq
              pkgs.ripgrep
              pkgs.strace
            ];
          } ''
            shell_package=${componentPackages.sleepy-shell}
            locker_package=${componentPackages.sleepy-locker}
            appearance_cli=${componentPackages.sleepy-appearance-cli}
            test -x "$shell_package/bin/sleepy-shell"
            test -x "$shell_package/bin/sleepy-shell-ipc"
            test -x "$appearance_cli/bin/sleepy"
            test -x "$locker_package/bin/sleepy-locker"
            test -f "$locker_package/share/sleepy-locker/LockRoot.qml"
            test -f "$locker_package/lib/qt6/qml/Sleepy/Locker/Native/qmldir"
            test -f "$shell_package/share/sleepy-desktop/services/IconRegistry.qml"
            test -f "$shell_package/share/sleepy-desktop/direct-integrations.json"
            test -f "$shell_package/share/sleepy-desktop/runtime-command-paths.json"
            test -f "$shell_package/share/doc/sleepy-desktop/NOTICE"
            test -d "${nativePlugin}/${pkgs.qt6.qtbase.qtQmlPrefix}/Sleepy"
            if [[ -f "$shell_package/share/sleepy-desktop/LICENSE" ]]; then
              test -f "$shell_package/share/doc/sleepy-desktop/LICENSE"
            fi
            test -f '${artworkManifest}'
            test "$(jq -er '.version' '${artworkManifest}')" = 1
            rg -F '${artworkRoot}' \
              "$shell_package/share/sleepy-desktop/services/IconRegistry.qml"
            rg -F '${artworkManifest}' \
              "$shell_package/share/sleepy-desktop/services/IconRegistry.qml"
            rg -F '${sessionPackage}/bin' "$shell_package/bin/sleepy-shell"
            bash ${self}/tests/packaged-ipc-smoke.sh \
              "$shell_package/bin/sleepy-shell-ipc" \
              "${quickshellWithModules}/bin/qs" \
              "$shell_package/share/sleepy-desktop/shell.qml"
            if rg '@sleepy[A-Za-z]+@' "$shell_package/share/sleepy-desktop"; then
              exit 1
            fi
            touch "$out"
          '';

          preview = pkgs.runCommand "sleepy-desktop-preview-contracts" {
            nativeBuildInputs = [ pkgs.coreutils pkgs.gnugrep ];
          } ''
            preview_package=${componentPackages.sleepy-settings-preview}
            test -x "$preview_package/bin/sleepy-settings-preview"
            preview_log="$TMPDIR/sleepy-preview.log"
            set +e
            QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
              timeout 3 "$preview_package/bin/sleepy-settings-preview" \
                >"$preview_log" 2>&1
            preview_status=$?
            set -e
            cat "$preview_log"
            if grep -Fq 'Unsupported image format' "$preview_log" || \
                grep -Fq 'QML Image:' "$preview_log"; then
              printf 'packaged preview emitted a QML image decoding error\n' >&2
              exit 1
            fi
            if [[ $preview_status -ne 124 ]]; then
              printf 'packaged preview exited unexpectedly with status %s\n' "$preview_status" >&2
              exit 1
            fi
            touch "$out"
          '';
        });
    };
}
