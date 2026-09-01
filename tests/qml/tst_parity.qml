import QtQuick 6.0
import QtTest 1.3

TestCase {
    id: testCase
    name: "Task10Parity"

    Component {
        id: stateFactory
        QtObject {
            property string outputId: "DP-1"
            property var monitor: ({"id": "DP-1", "name": "DP-1", "width": 1280,
                "height": 800, "scale": 1, "focused": true})
            property var workspaceRows: [
                {"id": "1", "name": "1", "monitorId": "DP-1", "focused": true},
                {"id": "special-music", "name": "special:music",
                    "monitorId": "DP-1", "focused": false}
            ]
            property var windows: [
                {"id": "window-main", "title": "Terminal", "applicationId": "com.term",
                    "workspaceId": "1", "focused": true, "fullscreen": false,
                    "floating": false, "pinned": false, "grouped": false},
                {"id": "window-other", "title": "Browser", "applicationId": "org.browser",
                    "workspaceId": "2", "focused": false, "fullscreen": false,
                    "floating": false, "pinned": false, "grouped": false}
            ]
            property var compositorActions: ({"focusWindow": true, "moveWindowToWorkspace": true,
                "closeWindow": true, "focusWorkspace": true,
                "moveWorkspaceToMonitor": true, "toggleFullscreen": true,
                "toggleFloating": true, "togglePinned": true, "toggleGroup": true,
                "exit": true})
            property bool busy: false
            property bool idleInhibited: false
            property bool gameMode: false
            property var recordingState: ({"status": "inactive"})
            property bool idleInhibitAvailable: true
            property bool gameModeAvailable: true
            property bool recordingAvailable: true
            property bool screenshotAvailable: true
            property bool colorPickerAvailable: true
            property bool sessionAvailable: true
            property string reducedMotion: ""
            property bool opaque: false
            property string currentWallpaperId: "wallpaper:night"
            property var sent: []

            function record(family, action, data) {
                const next = sent.slice();
                next.push({"family": family, "action": action, "data": data || {}});
                sent = next;
                return true;
            }
            function setIdleInhibited(enabled) {
                return record("utility", "setIdleInhibited", {"enabled": enabled});
            }
            function startRecording() {
                return record("utility", "startRecording", {"outputId": outputId});
            }
            function pauseRecording() { return record("utility", "pauseRecording"); }
            function stopRecording() { return record("utility", "stopRecording"); }
            function takeScreenshot() {
                return record("utility", "screenshot", {"outputId": outputId});
            }
            function pickColor() { return record("utility", "pickColor"); }
            function setGameMode(enabled) {
                return record("utility", "setGameMode", {"enabled": enabled});
            }
            function focusWindow(id) {
                return record("compositor", "focusWindow", {"windowId": id});
            }
            function closeWindow(id) {
                return record("compositor", "closeWindow", {"windowId": id});
            }
            function toggleWindowFullscreen(id) {
                return record("compositor", "toggleFullscreen", {"windowId": id});
            }
            function toggleWindowFloating(id) {
                return record("compositor", "toggleFloating", {"windowId": id});
            }
            function toggleWindowPinned(id) {
                return record("compositor", "togglePinned", {"windowId": id});
            }
            function toggleWindowGroup(id) {
                return record("compositor", "toggleGroup", {"windowId": id});
            }
            function performSession(action) {
                return record("session", action);
            }
        }
    }

    function load(path, state, extra) {
        const component = Qt.createComponent(path);
        verify(component.status === Component.Ready, component.errorString());
        const properties = Object.assign({
            "outputState": state,
            "colors": {"background": "#17131f", "surface": "#211c2b",
                "textPrimary": "#f7f3ff", "textSecondary": "#d4cde0",
                "accent": "#b9a7ff"}
        }, extra || {});
        const object = createTemporaryObject(component, testCase, properties);
        verify(object !== null, component.errorString());
        return object;
    }

    function test_utility_actions_cross_only_the_confirmed_output_boundary() {
        const state = createTemporaryObject(stateFactory, testCase);
        const view = load("../../src/modules/utilities/SleepyUtilities.qml", state);

        verify(view.requestIdleInhibited(true));
        verify(view.requestRecording());
        verify(view.requestScreenshot());
        verify(view.requestColorPicker());
        verify(view.requestGameMode(true));
        compare(state.idleInhibited, false);
        compare(state.gameMode, false);
        compare(JSON.stringify(state.sent), JSON.stringify([
            {"family":"utility","action":"setIdleInhibited","data":{"enabled":true}},
            {"family":"utility","action":"startRecording","data":{"outputId":"DP-1"}},
            {"family":"utility","action":"screenshot","data":{"outputId":"DP-1"}},
            {"family":"utility","action":"pickColor","data":{}},
            {"family":"utility","action":"setGameMode","data":{"enabled":true}}
        ]));
    }

    function test_window_info_is_per_output_and_routes_typed_actions_without_optimism() {
        const state = createTemporaryObject(stateFactory, testCase);
        const view = load("../../src/modules/windowinfo/SleepyWindowInfo.qml", state);

        compare(view.windowRows.length, 1);
        compare(view.windowRows[0].id, "window-main");
        verify(view.requestFocus("window-main"));
        verify(view.requestFullscreen("window-main"));
        verify(view.requestClose("window-main"));
        compare(view.windowRows[0].fullscreen, false);
        compare(JSON.stringify(state.sent), JSON.stringify([
            {"family":"compositor","action":"focusWindow","data":{"windowId":"window-main"}},
            {"family":"compositor","action":"toggleFullscreen","data":{"windowId":"window-main"}},
            {"family":"compositor","action":"closeWindow","data":{"windowId":"window-main"}}
        ]));
    }

    function test_window_controls_fail_closed_per_exact_compositor_capability() {
        const state = createTemporaryObject(stateFactory, testCase);
        state.compositorActions = Object.assign({}, state.compositorActions, {
            "toggleFullscreen": false,
            "closeWindow": false
        });
        const view = load("../../src/modules/windowinfo/SleepyWindowInfo.qml", state);
        const fullscreen = findChild(view, "windowAction:window-main:fullscreen");
        const close = findChild(view, "windowAction:window-main:close");
        const focus = findChild(view, "windowAction:window-main:focus");
        verify(fullscreen !== null && close !== null && focus !== null);
        verify(!fullscreen.enabled && !fullscreen.activeFocusOnTab);
        verify(!close.enabled && !close.activeFocusOnTab);
        verify(fullscreen.Accessible.ignored && close.Accessible.ignored);
        verify(focus.enabled && focus.activeFocusOnTab && !focus.Accessible.ignored);
        verify(!view.requestFullscreen("window-main"));
        verify(!view.requestClose("window-main"));
        verify(view.requestFocus("window-main"));
        compare(state.sent.length, 1);
        compare(state.sent[0].action, "focusWindow");
    }

    function test_background_respects_confirmed_effects_and_monitor_scale() {
        const state = createTemporaryObject(stateFactory, testCase);
        const view = load("../../src/modules/background/SleepyBackground.qml", state,
            {"reducedMotion": true, "opaque": true});
        compare(view.outputScale, 1);
        compare(view.motionDuration, 0);
        compare(view.renderedColor.toString(), "#17131f");
        compare(view.wallpaperId, "wallpaper:night");

        state.monitor = {"id": "DP-1", "name": "DP-1", "width": 1280,
            "height": 800, "scale": 2, "focused": true};
        compare(view.outputScale, 2);
    }

    function test_session_power_actions_require_explicit_second_confirmation() {
        const state = createTemporaryObject(stateFactory, testCase);
        const view = load("../../src/modules/session/SleepySession.qml", state);

        verify(view.requestAction("lock"));
        compare(state.sent.length, 1);
        verify(view.requestAction("powerOff"));
        compare(view.pendingAction, "powerOff");
        compare(state.sent.length, 1);
        verify(view.requestAction("powerOff"));
        compare(view.pendingAction, "");
        compare(JSON.stringify(state.sent), JSON.stringify([
            {"family":"session","action":"lock","data":{}},
            {"family":"session","action":"powerOff","data":{}}
        ]));
        verify(!view.requestAction("unlock"));
        compare(state.sent.length, 2);
    }
}
