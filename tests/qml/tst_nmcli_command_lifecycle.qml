// SPDX-License-Identifier: GPL-3.0-only
import QtQuick 6.0
import QtTest 1.0

TestCase {
    id: suite
    name: "NmcliCommandLifecycle"
    property int alive: 0
    property var activeProcesses: []

    function productionFunction(name, args) {
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl("../../src/services/Nmcli.qml"), false);
        request.send();
        const expression = new RegExp("    function " + name + "\\([^\\n]*\\)[^\\n]*\\{([\\s\\S]*?)\\n    \\}");
        const match = expression.exec(request.responseText);
        verify(match !== null, "missing production function " + name);
        return new Function(...args, match[1]);
    }

    function test_queries_never_schedule_another_refresh() {
        const classify = productionFunction("isMutationCommand", ["args"]);
        const queries = [
            ["nmcli", "radio", "wifi"], ["nmcli", "radio", "all"],
            ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"],
            ["nmcli", "connection", "show", "up"],
            ["nmcli", "connection", "show", "radio"],
            ["nmcli", "device", "show", "connect"],
            ["nmcli", "-g", "ACTIVE,SIGNAL,FREQ,SSID,BSSID,SECURITY", "d", "w"],
            ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status"]
        ];
        for (const command of queries)
            compare(classify(command), false, JSON.stringify(command));
    }

    function test_only_explicit_mutation_verbs_refresh() {
        const classify = productionFunction("isMutationCommand", ["args"]);
        for (const command of [
            ["nmcli", "radio", "wifi", "on"], ["nmcli", "radio", "wifi", "off"],
            ["nmcli", "connection", "up", "radio"],
            ["nmcli", "connection", "down", "up"],
            ["nmcli", "connection", "modify", "up", "connection.autoconnect", "yes"],
            ["nmcli", "connection", "delete", "radio"],
            ["nmcli", "device", "connect", "enp0s2"],
            ["nmcli", "device", "disconnect", "wlan0"],
            ["nmcli", "--ask", "device", "wifi", "connect", "radio"]
        ])
            compare(classify(command), true, JSON.stringify(command));
    }

    Component {
        id: processFactory
        QtObject {
            Component.onCompleted: suite.alive += 1
            Component.onDestruction: suite.alive -= 1
        }
    }

    function test_completed_process_objects_are_destroyed_and_removed() {
        const retire = productionFunction("retireCommandProcess", ["root", "proc"]);
        for (let batch = 0; batch < 5; batch++) {
            for (let i = 0; i < 100; i++) {
                const process = processFactory.createObject(suite);
                suite.activeProcesses.push(process);
                retire(suite, process);
            }
            compare(suite.activeProcesses.length, 0);
            tryCompare(suite, "alive", 0);
        }
    }
}
