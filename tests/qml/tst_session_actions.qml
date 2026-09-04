// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0
import QtTest 1.0

TestCase {
    id: testCase
    name: "SessionActionRouter"

    function source(relativePath) {
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl(relativePath), false);
        request.send();
        return request.responseText;
    }

    function fresh() {
        let qml = source("../../src/services/SessionActions.qml");
        qml = qml.replace("pragma Singleton", "");
        const router = Qt.createQmlObject(qml, testCase,
            Qt.resolvedUrl("../../src/services/SessionActions.qml"));
        verify(router !== null);
        return router;
    }

    function test_upstream_command_arrays_map_to_closed_sleepy_actions() {
        const router = fresh();
        compare(router.resolveAction(["loginctl", "terminate-user", ""]), "logout");
        compare(router.resolveAction(["systemctl", "suspend"]), "suspend");
        compare(router.resolveAction(["systemctl", "hibernate"]), "hibernate");
        compare(router.resolveAction(["systemctl", "poweroff"]), "powerOff");
        compare(router.resolveAction(["systemctl", "reboot"]), "reboot");
    }

    function test_arbitrary_commands_never_gain_session_authority() {
        const router = fresh();
        compare(router.resolveAction(["sh", "-c", "poweroff"]), "");
        compare(router.resolveAction(["systemctl", "poweroff", "--force"]), "");
        compare(router.resolveAction([]), "");
    }
}
