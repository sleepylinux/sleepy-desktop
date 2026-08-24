pragma ComponentBehavior: Bound

import QtQuick 6.0
import QtTest 1.0
import "../../src/drawers" as Drawers
import "../../src/services" as Services
import "../../src/theme" as Theme

TestCase {
    id: testCase
    name: "ControlCenter"
    when: windowShown
    width: 520
    height: 800

    readonly property url iconFixture: Qt.resolvedUrl("../fixtures/current-color.svg")

    Component {
        id: factory
        Drawers.ControlCenterView {
            width: 408
            height: 600
            tokens: Theme.ThemeTokens {}
            colors: Theme.Palette {}
            effects: Theme.EffectsPolicy { effectsProfile: "none" }
            iconRegistry: QtObject {
                function sourceFor(name) { return testCase.iconFixture; }
            }
            clockService: QtObject { property date currentTime: new Date(2026, 7, 24, 8, 3) }
            systemAdapter: Services.SystemAdapterCore {}
            presetAdapter: Services.PresetAdapterCore {}
            screenKey: "DP-1"
        }
    }

    function fixture(name) {
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl("../fixtures/" + name), false);
        request.send();
        return request.responseText;
    }

    function fresh() {
        const view = createTemporaryObject(factory, testCase);
        view.systemAdapter.beginSnapshot();
        view.systemAdapter.acceptSnapshotResult(1, 0,
            fixture("system-valid.json").replace('"generation": 7', '"generation": 1'), "", false);
        view.presetAdapter.acceptListResult(0, fixture("presets-valid.json"), "", false);
        return view;
    }

    function test_complete_sections_and_compact_overflow() {
        const view = fresh();
        verify(findChild(view, "sessionHeader") !== null);
        verify(findChild(view, "connectionsSection") !== null);
        verify(findChild(view, "audioSection") !== null);
        verify(findChild(view, "powerSection") !== null);
        verify(findChild(view, "mediaSection") !== null);
        verify(findChild(view, "presetSection") !== null);
        verify(findChild(view, "adapterDiagnostic") !== null);
        verify(findChild(view, "outputDevice-sink.living-room") !== null);
        verify(findChild(view, "powerProfile-balanced") !== null);
        verify(view.contentHeight > view.height);
        compare(findChild(view, "scrollIndicator").overflow, true);
        compare(view.drawerWidth, 408);
        compare(findChild(view, "outputDeviceSummary").value, "Living room");
        compare(findChild(view, "headerTime").text, "08:03");
    }

    function test_binding_header_uses_name_and_short_identifier() {
        const view = fresh();
        verify(view.openBindings("42db48b6-70c7-4fca-b36f-90658bdfba41"));
        const subtitle = findChild(view, "bindingPresetSubtitle");
        compare(subtitle.text, "Night work · 42db48b6");
        compare(subtitle.Accessible.description,
                "Preset identifier 42db48b6-70c7-4fca-b36f-90658bdfba41");
        compare(findChild(view, "bindingEditor").actions.length, 24);
        compare(findChild(view, "bindingRow-audio.volume.up").accelerator, "Unbound");
    }

    function test_unsupported_hardware_disables_only_its_control() {
        const view = fresh();
        const snapshot = JSON.parse(fixture("system-valid.json")
            .replace('"generation": 7', '"generation": 2'));
        snapshot.capabilities["display.brightness"] = "unavailable";
        snapshot.display.brightness = null;
        view.systemAdapter.beginSnapshot();
        view.systemAdapter.acceptSnapshotResult(2, 0, JSON.stringify(snapshot), "", false);
        compare(findChild(view, "brightnessControl").capabilityEnabled, false);
        compare(findChild(view, "networkToggle").capabilityEnabled, true);
    }

    function test_mutating_capability_shows_busy_without_optimistic_snapshot() {
        const view = fresh();
        const stable = view.systemAdapter.snapshot;
        view.systemAdapter.beginMutation("network.enabled", false);
        compare(view.systemAdapter.snapshot, stable);
        compare(findChild(view, "networkToggle").busy, true);
        view.systemAdapter.acceptMutationResult(2, 5, "", "failed", false);
        compare(findChild(view, "networkToggle").busy, false);
    }

    function test_pages_open_without_writing_preview_state() {
        const view = fresh();
        compare(view.page, "main");
        verify(view.openPresets());
        compare(view.page, "presets");
        verify(view.openBindings("42db48b6-70c7-4fca-b36f-90658bdfba41"));
        compare(view.page, "bindings");
        compare(view.bindingPresetId, "42db48b6-70c7-4fca-b36f-90658bdfba41");
        view.goBack();
        compare(view.page, "presets");
    }

    function test_builtin_binding_edit_requires_an_update_safe_copy() {
        const view = fresh();
        verify(view.openPresets());
        verify(!view.openBindings("builtin.sleepy"));
        compare(view.page, "presets");
    }

    function test_builtin_edit_duplicates_then_opens_confirmed_user_copy() {
        const view = fresh();
        const spy = signalSpy.createObject(view,
            {target: view, signalName: "presetCommandRequested"});
        view.openPresets();
        findChild(view, "presetRow-builtin.sleepy").editRequested("builtin.sleepy");
        compare(spy.signalArguments[0][0].join(" "),
                "sleepyctl presets duplicate builtin.sleepy Sleepy copy");
        const copy = JSON.parse(fixture("presets-valid.json")).presets[1];
        copy.id = "dd4d415e-5af0-4c12-aaf4-69e5bb893a61";
        copy.name = "Sleepy copy";
        verify(view.presetAdapter.acceptCommandResult(spy.signalArguments[0][0], 0,
            JSON.stringify({preset: copy}), "", false));
        compare(view.page, "bindings");
        compare(view.bindingPresetId, copy.id);
    }

    function test_inactive_preset_binding_edit_does_not_request_live_apply() {
        const view = fresh();
        verify(view.openBindings("42db48b6-70c7-4fca-b36f-90658bdfba41"));
        const editor = findChild(view, "bindingEditor");
        const spy = signalSpy.createObject(editor,
            {target: editor, signalName: "commandRequested"});
        editor.editingAction = "app.terminal.open";
        editor.draftAccelerator = "Mod+T";
        verify(editor.saveBinding());
        compare(spy.signalArguments[0][0].join(" "),
                "sleepyctl keybindings set --preset 42db48b6-70c7-4fca-b36f-90658bdfba41 app.terminal.open Mod+T");
    }

    function test_selecting_inactive_preset_does_not_activate_it() {
        const view = fresh();
        const spy = signalSpy.createObject(view,
            {target: view, signalName: "presetCommandRequested"});
        view.openPresets();
        const row = findChild(view,
            "presetRow-42db48b6-70c7-4fca-b36f-90658bdfba41");
        row.activated(row.presetId);
        compare(findChild(view, "presetManager").selectedPresetId,
                "42db48b6-70c7-4fca-b36f-90658bdfba41");
        compare(spy.count, 0);
    }

    function test_import_mode_and_export_payload_are_user_retrievable() {
        const view = fresh();
        view.openPresets();
        const manager = findChild(view, "presetManager");
        const spy = signalSpy.createObject(manager,
            {target: manager, signalName: "commandRequested"});
        manager.importMode = "replace";
        manager.transferPath = "/tmp/night.json";
        verify(manager.importPath());
        compare(spy.signalArguments[0][0].join(" "),
                "sleepyctl presets import --input /tmp/night.json --mode replace");
        view.presetAdapter.lastExportJson = '{\n  "preset": {}\n}';
        compare(findChild(view, "exportPayload").text, view.presetAdapter.lastExportJson);
    }

    function test_destructive_actions_require_cancel_or_explicit_confirm() {
        const view = fresh();
        const spy = signalSpy.createObject(view, {target: view, signalName: "sessionActionConfirmed"});
        verify(view.requestSessionAction("powerOff"));
        compare(view.page, "confirm");
        view.cancelConfirmation();
        compare(spy.count, 0);
        compare(view.page, "main");
        view.requestSessionAction("reboot");
        view.confirmSessionAction();
        compare(spy.count, 1);
        compare(spy.signalArguments[0][0], "reboot");
        compare(spy.signalArguments[0][1], "confirmed");
    }

    function test_confirmation_cancel_restores_invoking_focus() {
        const view = fresh();
        view.forceInitialFocus();
        findChild(view, "logoutButton").forceActiveFocus();
        tryCompare(view, "focusKey", "logout");
        verify(view.requestSessionAction("logout"));
        view.cancelConfirmation();
        tryCompare(findChild(view, "logoutButton"), "activeFocus", true);
    }

    function test_unavailable_session_action_is_disabled_and_not_routable() {
        const view = fresh();
        const snapshot = JSON.parse(fixture("system-valid.json")
            .replace('"generation": 7', '"generation": 2'));
        snapshot.sessionActions.logout = "unavailable";
        view.systemAdapter.beginSnapshot();
        view.systemAdapter.acceptSnapshotResult(2, 0, JSON.stringify(snapshot), "", false);
        compare(findChild(view, "logoutButton").enabled, false);
        verify(!view.requestSessionAction("logout"));
        compare(view.page, "main");
    }

    function test_power_menu_is_non_destructive_until_a_choice_is_confirmed() {
        const view = fresh();
        const spy = signalSpy.createObject(view, {target: view, signalName: "sessionActionConfirmed"});
        verify(view.openPowerMenu());
        compare(view.page, "power");
        compare(spy.count, 0);
        verify(view.choosePowerAction("reboot"));
        compare(view.page, "confirm");
        compare(spy.count, 0);
        view.confirmSessionAction();
        compare(spy.count, 1);
        compare(spy.signalArguments[0][0], "reboot");
    }

    Component { id: signalSpy; SignalSpy {} }
}
