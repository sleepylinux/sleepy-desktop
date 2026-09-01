import QtQuick 6.0
import QtTest 1.3

TestCase {
    id: testCase
    name: "CoreIpcRouter"

    Component {
        id: outputFactory
        QtObject {
            property var monitor: ({"id": "DP-1", "focused": true})
            property string activeOverlay: ""
            property bool mediaAvailable: true
            property bool sessionAvailable: true
            property var players: [{"id": "player-1", "playing": true}]
            property var calls: []
            function record(name, value) {
                calls = calls.concat([{"name": name, "value": value}]);
                return true;
            }
            function toggleOverlay(name) { return record("overlay", name); }
            function openOverlay(name) {
                activeOverlay = name;
                return record("open", name);
            }
            function setNexusTab(name) { return record("nexusTab", name); }
            function closeOverlay() { activeOverlay = ""; record("close", ""); }
            function controlPlayer(id, action) {
                return record("media", {"id": id, "action": action});
            }
            function performSession(action) { return record("session", action); }
        }
    }

    function createRouter(outputs) {
        const component = Qt.createComponent("../../src/core/CoreIpcRouter.qml");
        verify(component.status === Component.Ready, component.errorString());
        const router = createTemporaryObject(component, testCase, {"outputStates": outputs});
        verify(router !== null, component.errorString());
        return router;
    }

    function test_routes_closed_operations_only_to_unique_focused_output() {
        const focused = createTemporaryObject(outputFactory, testCase);
        const other = createTemporaryObject(outputFactory, testCase);
        other.monitor = {"id": "HDMI-A-1", "focused": false};
        const router = createRouter([focused, other]);

        verify(router.toggle("launcher"));
        verify(router.toggle("notifications"));
        verify(router.toggle("dashboard"));
        verify(router.toggle("nexus"));
        verify(router.media("next"));
        verify(router.lock());
        verify(router.openPowerMenu());
        verify(router.close());
        verify(!router.toggle("unknown"));
        verify(!router.media("seek"));
        compare(typeof router.session, "undefined");
        compare(typeof router.suspend, "undefined");
        compare(typeof router.logout, "undefined");
        compare(typeof router.reboot, "undefined");
        compare(typeof router.powerOff, "undefined");
        compare(typeof router.unlock, "undefined");
        compare(other.calls.length, 0);
        compare(JSON.stringify(focused.calls), JSON.stringify([
            {"name":"overlay","value":"launcher"},
            {"name":"overlay","value":"notifications"},
            {"name":"overlay","value":"dashboard"},
            {"name":"overlay","value":"nexus"},
            {"name":"media","value":{"id":"player-1","action":"next"}},
            {"name":"session","value":"lock"},
            {"name":"nexusTab","value":"session"},
            {"name":"open","value":"nexus"},
            {"name":"close","value":""}
        ]));
    }

    function test_power_menu_is_idempotently_opened_when_nexus_is_already_visible() {
        const output = createTemporaryObject(outputFactory, testCase);
        output.activeOverlay = "nexus";
        const router = createRouter([output]);

        verify(router.openPowerMenu());
        compare(output.activeOverlay, "nexus");
        compare(JSON.stringify(output.calls), JSON.stringify([
            {"name":"nexusTab","value":"session"},
            {"name":"open","value":"nexus"}
        ]));
    }

    function test_ambiguous_or_missing_focus_fails_closed() {
        const first = createTemporaryObject(outputFactory, testCase);
        const second = createTemporaryObject(outputFactory, testCase);
        second.monitor = {"id": "HDMI-A-1", "focused": true};
        let router = createRouter([first, second]);
        verify(!router.toggle("launcher"));
        verify(!router.media("playPause"));
        verify(!router.lock());
        verify(!router.openPowerMenu());

        first.monitor = {"id": "DP-1", "focused": false};
        second.monitor = {"id": "HDMI-A-1", "focused": false};
        router.outputStates = [first, second];
        verify(!router.toggle("launcher"));
        verify(!router.close());
        compare(first.calls.length, 0);
        compare(second.calls.length, 0);
    }

    function test_media_and_session_degradation_are_independent() {
        const output = createTemporaryObject(outputFactory, testCase);
        const router = createRouter([output]);
        output.mediaAvailable = false;
        verify(!router.media("previous"));
        verify(router.lock());
        output.mediaAvailable = true;
        output.players = [];
        verify(!router.media("previous"));
        output.sessionAvailable = false;
        verify(!router.lock());
    }
}
