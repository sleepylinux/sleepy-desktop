# sleepy-desktop

## License

Licensed under GPL-3.0-only. See [LICENSE](LICENSE).

The Sleepy desktop Control Center: a permanently visible inset rail,
descriptor-driven per-screen drawers, confirmed system controls, durable named
preset and keybinding management, and a non-persistent visual gallery. The QML
is split into focused theme, service, surface,
panel, drawer, widget, and preview modules so later surfaces share one
screen-scoped, single-open-surface controller.

The default look is a layered cozy-night lavender glass palette built on a
12 px grid, 22 px shell radii, and 16 px inner radii. Full, reduced, and none
effects profiles keep a high-opacity contrast floor; none is opaque and has no
decorative motion. All controls are keyboard reachable. Reduced motion changes
non-essential transition duration to zero. Network, Bluetooth, audio,
microphone, output, brightness, night light, power, battery, media, and session
controls reflect typed adapter state; unsupported hardware disables only the
affected control.

## Runtime contract

`SessionAdapter.qml` remains the appearance-settings boundary. It runs
`sleepyctl settings show` on startup and `sleepyctl presets activate <id> --apply` when
requested, validates the complete schema-v1 document, and falls back to a new
immutable default snapshot on timeout, nonzero exit, or malformed output. The
shell starts immediately and logs the diagnostic instead of waiting for the
session service. `SystemAdapter.qml` sends client-generated positive request
generations to the typed `sleepyctl system`/`session` facade, preserves the
last valid snapshot, and applies no optimistic mutation. `PresetAdapter.qml`
owns preset and keybinding transport; editing a built-in first creates an
update-safe user copy. Preset selection and activation are separate operations,
and the binding editor exposes every SDK semantic action, including unbound ones.

Artwork is requested only by reviewed logical manifest names. At runtime the
icon registry safely loads the pinned installed manifest; there is no second
hardcoded asset table. The Nix build substitutes its artwork root and manifest
store paths. Packaged Sleepy code reads that substituted manifest and validates
every entry before resolution. The runner's `QML_XHR_ALLOW_FILE_READ=1` setting
enables local-file XHR process-wide for QML in that process; it is not an OS
sandbox or a path allowlist. Sleepy QML never refers to a source checkout or
workstation path. Functional SVGs are tinted through Qt 6 `MultiEffect`, with a
visible geometric fallback when resolution or manifest validation fails.
The pinned `sleepy-sdk` settings, preset, and system schemas are installed
alongside the QML.

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

The packaged gallery changes appearance, effects, reduced-motion, compact,
preset, and binding-conflict scenes in local memory only. It never creates a
process adapter and cannot persist:

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
`5dc792faea9d743fabbb576ae1b25ed7e1f729f9` and the reviewed public
`sleepy-artwork` flake at
`bd0d9ac2261b4dc2c3ad41e6d3d898b22cda2a85`. Desktop checks consume its exact
`checks.<system>.assets` output and expose exact `qml`, `package`, and `preview`
checks for root integration.
