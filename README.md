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

M3 adds a reconnectable snapshot-first v2 event client. It runs the fixed argv
`sleepyctl events watch --format ndjson`, rejects unknown versions and payloads,
requires monotonic daemon generations, and keeps capability failures local.
The active shell no longer polls Niri or system state: workspace/focus routing
and Control Center readback are derived from daemon events. Mutating M2
controls retain their one-release compatibility client and never update the UI
until confirmed readback arrives.

Quickshell's native local `Socket` type connects directly to the private
`daily.sock`, `osd.sock`, and `theme.sock` boundaries. Daily requests are UUID
correlated and expose only launcher index actions, typed Niri commands,
calendar, weather, and explicit geocoding submit; arbitrary command text is
not executable. OSD replay/live publications remain ordered per output. Theme
candidates are applied to memory first and acknowledged with the matching
typed request; failures never replace durable theme state from QML.

Notifications, launcher, overview, widgets, and personalization are registered
through the same per-screen surface registry. Lists implement keyboard
navigation, Home/End, Escape, accessible names/roles, and output-local focus
restoration. Loading, empty, offline, stale, error, unsupported and other
capability states are not collapsed into success. A deterministic two-output
gallery fixture covers DND/grouping, OSD overflow, palettes, provider states,
and every effects mode.

`SessionAdapter.qml` remains the appearance-settings boundary. It runs
`sleepyctl settings show` on startup and `sleepyctl presets activate <id> --apply` when
requested, validates the complete schema-v1 document, and falls back to a new
immutable default snapshot on timeout, nonzero exit, or malformed output. The
shell starts immediately and logs the diagnostic instead of waiting for the
session service. `SystemAdapter.qml` sends client-generated positive request
generations to the typed `sleepyctl system`/`session` facade, preserves the
last valid snapshot, and applies no optimistic mutation. `PresetAdapter.qml`
owns preset and keybinding transport; editing a built-in first creates an
update-safe user copy through Task 3's atomic COW apply operation when that
built-in is active; an inactive built-in asks to be activated first. Preset
selection and activation are separate operations, and the binding editor
exposes every SDK semantic action, including unbound ones.

Artwork is requested only by reviewed logical manifest names. At runtime the
icon registry safely loads the pinned installed manifest; there is no second
hardcoded asset table. The Nix build substitutes its artwork root and manifest
store paths. Packaged Sleepy code reads that substituted manifest and validates
every entry before resolution. The runner's `QML_XHR_ALLOW_FILE_READ=1` setting
enables local-file XHR process-wide for QML in that process; it is not an OS
sandbox or a path allowlist. Sleepy QML never refers to a source checkout or
workstation path. Functional SVGs are tinted through Qt 6 `MultiEffect`, with a
visible geometric fallback when resolution or manifest validation fails.
The pinned `sleepy-sdk` settings, preset, system, desktop-event-v3, and
desktop-command-v3 schemas are installed alongside the QML.

Task 6 packages intentionally run a minimal daemon-backed shell graph while
the imported visual modules are audited in later porting tasks. Quarantined
source remains in the repository for provenance, but the production shell does
not import `src/modules/**`, native `Sleepy.Services`, or native
`Sleepy.Models`, and production installs remove `modules/lock` plus
`assets/pam.d`.

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
`d935d3d83ef3c01627cd315230607c4b04554d42` and the reviewed public
`sleepy-artwork` flake at
`175314b9c236c1b412e8e1ebc54bbe3937b0c90d`. Desktop checks consume its exact
`checks.<system>.assets` output and expose exact `qml`, `package`, and `preview`
checks for root integration. The runtime also pins `sleepy-session` at
`25c83eaa618570681d9e5f442f0c2bff727ae0ce` and prefixes its exact package
`bin` directory so every packaged runner resolves the reviewed `sleepyctl`.

These revisions are the reviewed public M3 component commits merged to each
repository's `main` branch. Desktop publication and root integration pin these
exact immutable commits and rerun every component check.
