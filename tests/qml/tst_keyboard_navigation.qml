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

    Component { id: signalSpy; SignalSpy {} }
}
