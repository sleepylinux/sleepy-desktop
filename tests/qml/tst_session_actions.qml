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
        compare(router.resolveAction(["loginctl", "lock-session"]), "lock");
        compare(router.resolveAction(["suspendThenHibernate"]), "suspendThenHibernate");
        compare(router.resolveAction(["systemctl", "poweroff"]), "powerOff");
        compare(router.resolveAction(["systemctl", "reboot"]), "reboot");
    }

    function test_arbitrary_commands_never_gain_session_authority() {
        const router = fresh();
        compare(router.resolveAction(["sh", "-c", "poweroff"]), "");
        compare(router.resolveAction(["systemctl", "poweroff", "--force"]), "");
        compare(router.resolveAction([]), "");
    }

    function test_launcher_daemon_rejection_does_not_execute_protected_argv() {
        const qml = source("../../src/modules/launcher/services/Actions.qml");
        const marker = "function onClicked(list: AppList): void {";
        const body = qml.slice(qml.indexOf(marker) + marker.length, qml.lastIndexOf("\n        }"));
        const invoke = new Function("command", "dangerous", "list", "SessionActions", "Quickshell", body);
        const router = fresh();
        let calls = [];
        const session = {
            resolveAction: command => router.resolveAction(command),
            perform: action => { calls.push(action); return false; }
        };
        const quickshell = {execDetached: command => { calls.push("raw"); }};
        for (const command of [["loginctl", "lock-session"], ["suspendThenHibernate"]])
            invoke(command, false, {screenState: {launcher: true}}, session, quickshell);
        compare(JSON.stringify(calls), JSON.stringify(["lock", "suspendThenHibernate"]));
    }
}
