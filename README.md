# sleepy-desktop

## License

Licensed under GPL-3.0-only. See [LICENSE](LICENSE).

The first polished Sleepy desktop slice: a permanently visible inset rail, an
aligned quick-settings drawer, and a non-persistent settings preview. The QML
is split into focused theme, service, panel, drawer, widget, and preview
modules so future left or right surfaces can register with the same
single-open-surface controller.

The default look is a matte cozy-night lavender palette built on a 12 px grid,
22 px shell radii, and 16 px inner radii. All controls are keyboard reachable.
Reduced motion changes non-essential transition duration to zero. Network,
Bluetooth, night light, focus, volume, and brightness controls remain view-only
until a capability adapter explicitly reports support.

## Runtime contract

`SessionAdapter.qml` is the only settings boundary. It runs
`sleepyctl settings show` on startup and `sleepyctl presets activate <id>` when
requested, validates the complete schema-v1 document, and falls back to a new
immutable default snapshot on timeout, nonzero exit, or malformed output. The
shell starts immediately and logs the diagnostic instead of waiting for the
session service.

Artwork is requested by the logical name `branding.primaryMark`. The Nix build
resolves that name from the pinned `sleepy-artwork` manifest and substitutes the
resulting store path; QML never refers to a source checkout or workstation
path. The pinned `sleepy-sdk` settings schema is installed alongside the QML.

## Validate

The validator requires Qt 6 tooling and a discoverable Quickshell QML module.
It intentionally rejects a generic Qt 5 `qmllint` or `qmltestrunner`.
It discovers Nix/custom prefixes from the resolved Quickshell and Qt tool
paths. If discovery is ambiguous, set `SLEEPY_QUICKSHELL_IMPORT_PATH` to the
QML import root containing `Quickshell/qmldir`; an invalid explicit path is a
hard failure.

```sh
bash tests/run.sh
bash tests/validate-qml-paths.sh
bash scripts/validate-qml.sh
bash -n tests/run.sh tests/validate-qml-paths.sh scripts/validate-qml.sh \
  scripts/lib/qml-tooling.sh
```

The behavior tests use Qt's real QML test runner; they do not inspect QML source
text. Their negative fixtures cover unknown settings keys and malformed JSON.

## Preview

The packaged preview changes appearance, effects, and reduced-motion values in
local memory only. It never creates a session adapter and cannot persist:

```sh
nix run .#sleepy-settings-preview
```

Without Nix, from a checkout with Qt 6 QML available, the exact command is:

```sh
/usr/lib/qt6/bin/qml -I "$PWD/src" "$PWD/src/preview/main.qml"
```

The source-tree command will show an unresolved artwork placeholder; the
packaged command resolves the lunar mark through the artwork manifest. Neither
command starts or replaces the user's Quickshell process.

## Packages

```sh
nix build .#sleepy-shell
nix build .#sleepy-settings-preview
nix build .#default
```

The flake pins `sleepy-sdk` at
`4c4f7989b957f41f3748ddfb092b0348e2ba9e88` and `sleepy-artwork` at
`7785ac5dac0daa6ac1a619f1e2a9a1b1d1374da1`.
