{
  description = "Sleepy Quickshell desktop rail and quick-settings slice";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    sleepy-sdk = {
      url = "github:sleepylinux/sleepy-sdk/2edbe8310eee69c40e4f75924da67a57942bd1c3";
      flake = false;
    };

    sleepy-artwork = {
      url = "github:sleepylinux/sleepy-artwork/0dd59cc9d8a77700f7a415997e3dcde396f55e99";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, sleepy-sdk, sleepy-artwork }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          installRoot = "share/sleepy-desktop";

          mkDesktopPackage = { pname, runner, runnerFlags }:
            pkgs.stdenvNoCC.mkDerivation {
              inherit pname;
              version = "0.1.0";
              src = ./.;
              nativeBuildInputs = [ pkgs.jq pkgs.makeWrapper ];
              dontBuild = true;

              installPhase = ''
                runHook preInstall

                mkdir -p "$out/${installRoot}" "$out/bin" "$out/${installRoot}/contracts"
                cp -R src/. "$out/${installRoot}/"
                install -Dm644 \
                  "${sleepy-sdk}/schemas/settings.schema.json" \
                  "$out/${installRoot}/contracts/settings.schema.json"

                artwork_manifest="${sleepy-artwork}/branding/manifest.json"
                primary_mark_relative="$(jq -er '.assets["branding.primaryMark"]' "$artwork_manifest")"
                case "$primary_mark_relative" in
                  /*|*..*)
                    printf 'branding.primaryMark must be a package-relative manifest path\n' >&2
                    exit 1
                    ;;
                esac
                primary_mark="${sleepy-artwork}/$primary_mark_relative"
                if [[ ! -f "$primary_mark" ]]; then
                  printf 'branding.primaryMark is missing: %s\n' "$primary_mark" >&2
                  exit 1
                fi

                while IFS= read -r qml_file; do
                  substituteInPlace "$qml_file" \
                    --replace-fail '@sleepyPrimaryMark@' "$primary_mark"
                done < <(grep -rl '@sleepyPrimaryMark@' "$out/${installRoot}")

                makeWrapper "${runner}" "$out/bin/${pname}" \
                  --add-flags "${runnerFlags "$out/${installRoot}"}"

                runHook postInstall
              '';

              passthru = {
                sdkRevision = "2edbe8310eee69c40e4f75924da67a57942bd1c3";
                artworkRevision = "0dd59cc9d8a77700f7a415997e3dcde396f55e99";
              };

              meta = {
                description = "Sleepy cozy-night Quickshell desktop slice";
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
        });
    };
}
