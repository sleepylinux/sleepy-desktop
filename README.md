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

## Full shell graph

The production entry point loads the complete modular shell graph: bar and
popouts, launcher modes, dashboard tabs, sidebar, notifications, Nexus pages
and dialogs, OSDs, session controls, utilities, window information,
wallpaper/style controls and the secure lock presentation. The source remains
split under `src/modules`, `src/services`, `src/components`, and `src/config`;
Sleepy-specific transport adapters are separate from the visual components, so
a provider or individual surface can be changed without forking a monolithic
entry point.

The visual and interaction baseline is Caelestia Shell v2.4.0. Production files
are Sleepy-owned and import only Sleepy QML modules and packages. There is no
runtime Caelestia executable, configuration directory, IPC service, plugin, or
network bootstrap. The only intentional visible differences are Sleepy names
and branding; deterministic reference tests mask only those declared regions.

`ServiceLoader.qml` composes the provider layer. Compositor state and dispatch
use `Quickshell.Hyprland` and fixed `hyprctl` queries; network uses fixed-argv
`nmcli`; audio, media, tray, notifications and power telemetry use native
Quickshell Qt/D-Bus models. Brightness and VPN adapters select one installed
backend and read it back after mutation. Wallpaper and colour-scheme state use
the modular `sleepy` appearance CLI. The complete executable map is substituted
to immutable Nix store paths when the package is built, so an empty XDG home
cannot accidentally resolve a Caelestia helper from `PATH`.

Protected actions are deliberately outside that direct-provider layer.
Recording lifecycle and confined deletion, idle inhibition, game mode, lock,
suspend, logout, reboot and power-off are typed `sleepy-sessiond` requests.
The lock view receives redacted presentation state only; `sleepy-locker` owns
the ext-session-lock protocol and PAM conversation, and no QML API can unlock
the session.

## Validate

The validator requires Qt 6 tooling and a discoverable Quickshell QML module.
It intentionally rejects a generic Qt 5 `qmllint` or `qmltestrunner`.
It discovers Nix/custom prefixes from the resolved Quickshell and Qt tool
paths. If discovery is ambiguous, set `SLEEPY_QUICKSHELL_IMPORT_PATH` to the
QML import root containing `Quickshell/qmldir`; an invalid explicit path is a
hard failure.

```sh
bash tests/run.sh
bash tests/packaged-full-shell-smoke.sh
bash tests/reference-contract.sh
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
The reference comparator additionally checks exact RGBA pixels outside the
Sleepy branding mask, surface bounds and ordered animation frames/timestamps.
Real reference captures and the real virt-manager acceptance remain separate
environment gates; unit fixtures do not stand in for those gates.

## Customization and upstream updates

User-adjustable values live in the typed Sleepy settings/config layer and XDG
Sleepy state, not in the entry point. Surface code can be edited independently
inside its module directory; provider changes belong in `src/services` or the
Sleepy transport adapters. Add an executable only through the direct-integration
registry and Nix runtime command map, with a fixed argv contract, explicit
secret policy, readback strategy and failure test. Add a protected transition
to `sleepy-sdk` first, implement it in `sleepy-sessiond`, and expose only the
typed command to QML.

To import a newer Caelestia release, fetch an immutable upstream tag/commit into
a separate reference tree, regenerate the provenance/parity inventory, and
port changes by module rather than replacing Sleepy transport or security
boundaries. Review every new command, native plugin, state path and secret flow;
rename runtime identities to Sleepy; update deterministic fixtures and branding
masks; then run component tests, exact reference capture comparison and the real
virt-manager acceptance. The upstream source is a review reference only and is
never a runtime dependency.

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
`1ee5b424887eb6f7acfe3b931b37a2c610ff6498` and the reviewed public
`sleepy-artwork` flake at
`175314b9c236c1b412e8e1ebc54bbe3937b0c90d`. Desktop checks consume its exact
`checks.<system>.assets` output and expose exact `qml`, `package`, and `preview`
checks for root integration. The runtime also pins `sleepy-session` at
`125efe94e4ef9b22dea1369c4bbb11d4cad80237` and prefixes its exact package
`bin` directory so every packaged runner resolves the reviewed `sleepyctl`.

These revisions are the reviewed public M3 component commits merged to each
repository's `main` branch. Desktop publication and root integration pin these
exact immutable commits and rerun every component check.
