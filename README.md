# sleepy-desktop

## License

Licensed under GPL-3.0-only. See [LICENSE](LICENSE).

The Sleepy desktop material and surface foundation: a permanently visible
inset rail, descriptor-driven left or right drawers, and a non-persistent
settings preview. The QML is split into focused theme, service, surface,
panel, drawer, widget, and preview modules so later surfaces share one
screen-scoped, single-open-surface controller.

The default look is a layered cozy-night lavender glass palette built on a
12 px grid, 22 px shell radii, and 16 px inner radii. Full, reduced, and none
effects profiles keep a high-opacity contrast floor; none is opaque and has no
decorative motion. All controls are keyboard reachable. Reduced motion changes
non-essential transition duration to zero. Network,
Bluetooth, night light, focus, volume, and brightness controls remain view-only
until a capability adapter explicitly reports support.

## Runtime contract

`SessionAdapter.qml` is the only settings boundary. It runs
`sleepyctl settings show` on startup and `sleepyctl presets activate <id>` when
requested, validates the complete schema-v1 document, and falls back to a new
immutable default snapshot on timeout, nonzero exit, or malformed output. The
shell starts immediately and logs the diagnostic instead of waiting for the
session service.

Artwork is requested only by reviewed logical manifest names. The Nix build
substitutes the pinned artwork root and manifest store paths; QML never refers
to a source checkout or workstation path. Functional SVGs are tinted through
Qt 6 `MultiEffect`, with a visible geometric fallback when resolution fails.
The pinned `sleepy-sdk` settings schema is installed alongside the QML.

## Validate

The validator requires Qt 6 tooling and a discoverable Quickshell QML module.
It intentionally rejects a generic Qt 5 `qmllint` or `qmltestrunner`.
It discovers Nix/custom prefixes from the resolved Quickshell and Qt tool
paths. If discovery is ambiguous, set `SLEEPY_QUICKSHELL_IMPORT_PATH` to the
QML import root containing `Quickshell/qmldir`; an invalid explicit path is a
hard failure.

```sh
bash tests/run.sh
bash tests/dependencies.sh
bash tests/validate-qml-paths.sh
bash scripts/validate-qml.sh
bash -n tests/run.sh tests/dependencies.sh tests/validate-qml-paths.sh scripts/validate-qml.sh \
  scripts/lib/qml-tooling.sh
```

The behavior tests use Qt's real QML test runner; they do not inspect QML source
text. Their negative fixtures cover unknown settings keys and malformed JSON.
The main suite uses the Qt Quick software backend, then performs a focused RHI
pass with Mesa software rendering for the real `MultiEffect` pixel assertion.

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
`2edbe8310eee69c40e4f75924da67a57942bd1c3` and the reviewed public
`sleepy-artwork` flake at
`bd0d9ac2261b4dc2c3ad41e6d3d898b22cda2a85`. Desktop checks consume its exact
`checks.<system>.assets` output and expose exact `qml`, `package`, and `preview`
checks for root integration.
