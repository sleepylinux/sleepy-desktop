pragma ComponentBehavior: Bound

import QtQuick 6.0
import QtTest 1.0
import "../../src/drawers" as Drawers
import "../../src/services" as Services
import "../../src/theme" as Theme

TestCase {
    id: testCase
    name: "ControlCenterKeyboard"
    when: windowShown
    width: 520
    height: 800
    readonly property url iconFixture: Qt.resolvedUrl("../fixtures/current-color.svg")

    Component {
        id: factory
        Drawers.ControlCenterView {
            width: 408; height: 700
            tokens: Theme.ThemeTokens {}
            colors: Theme.Palette {}
            effects: Theme.EffectsPolicy { effectsProfile: "none" }
            iconRegistry: QtObject { function sourceFor(name) { return testCase.iconFixture; } }
            clockService: QtObject { property date currentTime: new Date(2026, 7, 24, 8, 3) }
            systemAdapter: Services.SystemAdapterCore {}
            presetAdapter: Services.PresetAdapterCore {}
        }
    }

    function fixture(name) {
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl("../fixtures/" + name), false);
        request.send();
        return request.responseText;
    }

    function test_initial_focus_tab_arrows_home_end_and_disabled_skip() {
        const view = createTemporaryObject(factory, testCase);
        view.systemAdapter.beginSnapshot();
        view.systemAdapter.acceptSnapshotResult(1, 0,
            fixture("system-valid.json").replace('"generation": 7', '"generation": 1'),
            "", false);
        view.forceInitialFocus();
        tryCompare(findChild(view, "lockButton"), "activeFocus", true);
        compare(view.focusKey, "lock");
        keyClick(Qt.Key_Tab);
        compare(view.focusKey, "logout");
        keyClick(Qt.Key_Right);
        compare(view.focusKey, "power");
        view.presetAdapter.acceptListResult(0, fixture("presets-valid.json"), "", false);
        view.openPresets();
        tryCompare(findChild(view, "presetRow-builtin.sleepy"), "activeFocus", true);
        keyClick(Qt.Key_End);
        compare(view.focusKey, "preset-last");
        tryCompare(findChild(view, "presetRow-42db48b6-70c7-4fca-b36f-90658bdfba41"),
                   "activeFocus", true);
        keyClick(Qt.Key_Home);
        compare(view.focusKey, "preset-first");
        tryCompare(findChild(view, "presetRow-builtin.sleepy"), "activeFocus", true);
    }

    function test_escape_steps_back_then_closes() {
        const view = createTemporaryObject(factory, testCase);
        const spy = signalSpy.createObject(view, {target: view, signalName: "closeRequested"});
        view.openPresets();
        view.forceActiveFocus();
        keyClick(Qt.Key_Escape);
        compare(view.page, "main");
        keyClick(Qt.Key_Escape);
        compare(spy.count, 1);
    }

    function loadedView() {
        const view = createTemporaryObject(factory, testCase);
        view.systemAdapter.beginSnapshot();
        view.systemAdapter.acceptSnapshotResult(1, 0,
            fixture("system-valid.json").replace('"generation": 7', '"generation": 1'),
            "", false);
        view.presetAdapter.acceptListResult(0, fixture("presets-valid.json"), "", false);
        view.presetAdapter.activePresetId = "builtin.sleepy";
        return view;
    }

    function test_actual_grid_device_media_and_binding_focus_navigation() {
        const view = loadedView();
        const network = findChild(view, "networkToggle");
        network.forceActiveFocus();
        keyClick(Qt.Key_Right);
        tryCompare(findChild(view, "bluetoothToggle"), "activeFocus", true);
        keyClick(Qt.Key_Home);
        tryCompare(network, "activeFocus", true);

        const muteOutput = findChild(view, "muteOutputToggle");
        muteOutput.forceActiveFocus();
        keyClick(Qt.Key_End);
        tryCompare(findChild(view, "muteMicrophoneToggle"), "activeFocus", true);

        const firstDevice = findChild(view, "outputDevice-sink.living-room");
        firstDevice.forceActiveFocus();
        keyClick(Qt.Key_Down);
        tryCompare(findChild(view, "outputDevice-sink.headphones"), "activeFocus", true);
        keyClick(Qt.Key_Home);
        tryCompare(firstDevice, "activeFocus", true);

        const previous = findChild(view, "mediaControl-previous");
        previous.forceActiveFocus();
        keyClick(Qt.Key_End);
        tryCompare(findChild(view, "mediaControl-next"), "activeFocus", true);
        keyClick(Qt.Key_Left);
        tryCompare(findChild(view, "mediaControl-playPause"), "activeFocus", true);

        view.openPresets();
        const presetRow = findChild(view, "presetRow-builtin.sleepy");
        presetRow.forceActiveFocus();
        keyClick(Qt.Key_Tab);
        tryCompare(findChild(view, "presetAction-builtin.sleepy"), "activeFocus", true);
        keyClick(Qt.Key_Return);
        compare(view.page, "bindings");
        const firstBinding = findChild(view, "bindingRow-app.terminal.open");
        firstBinding.forceActiveFocus();
        keyClick(Qt.Key_End);
        tryCompare(findChild(view, "bindingRow-display.brightness.down"), "activeFocus", true);
        keyClick(Qt.Key_Home);
        tryCompare(firstBinding, "activeFocus", true);
    }

    function test_preset_action_tab_backtab_and_disabled_skip_do_not_trap() {
        const view = loadedView();
        view.openPresets();
        const builtin = findChild(view, "presetRow-builtin.sleepy");
        const builtinAction = findChild(view, "presetAction-builtin.sleepy");
        const user = findChild(view,
            "presetRow-42db48b6-70c7-4fca-b36f-90658bdfba41");
        builtin.forceActiveFocus();
        keyClick(Qt.Key_Tab);
        tryCompare(builtinAction, "activeFocus", true);
        keyClick(Qt.Key_Tab);
        tryCompare(user, "activeFocus", true);
        keyClick(Qt.Key_Backtab);
        tryCompare(builtinAction, "activeFocus", true);

        view.presetAdapter.activePresetId = user.presetId;
        builtin.forceActiveFocus();
        compare(builtinAction.enabled, false);
        keyClick(Qt.Key_Tab);
        tryCompare(user, "activeFocus", true);
        compare(builtinAction.activeFocus, false);
        keyClick(Qt.Key_Backtab);
        tryCompare(builtin, "activeFocus", true);
        compare(builtinAction.activeFocus, false);
    }

    Component { id: signalSpy; SignalSpy {} }
}
