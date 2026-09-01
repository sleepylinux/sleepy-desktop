import QtQuick 6.0
import QtTest 1.0

TestCase {
    id: testCase

    name: "ServiceClientLoad"

    Component { id: signalSpy; SignalSpy {} }

    function source(relativePath) {
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl(relativePath), false);
        request.send();
        return request.responseText;
    }

    function loadProductionClient() {
        let qml = source("../../src/services/DesktopClient.qml");
        qml = qml.replace("pragma Singleton", "");
        qml = qml.replace("import QtQuick 6.0",
            "import QtQuick 6.0\nimport \"../../src/services\" as Services");
        qml = qml.replace("DesktopProtocol {", "Services.DesktopProtocol {");
        qml = qml.replace(
            "readonly property DesktopReconnectPolicy reconnectPolicy: DesktopReconnectPolicy {",
            "readonly property Services.DesktopReconnectPolicy reconnectPolicy: Services.DesktopReconnectPolicy {");
        qml = qml.replace("property bool enabled: true", `property bool enabled: false
            property alias testSocket: root.desktopSocket`);
        const client = Qt.createQmlObject(qml, testCase, "ProductionDesktopReconnectClient");
        verify(client !== null);
        return client;
    }

    function test_00_desktop_client_loads_without_default_property_errors() {
        const component = Qt.createComponent("../../src/services/DesktopClient.qml");

        compare(component.status, Component.Ready, component.errorString());
    }

    function test_01_command_client_loads_without_default_property_errors() {
        const component = Qt.createComponent("../../src/services/CommandClient.qml");

        compare(component.status, Component.Ready, component.errorString());
    }

    function test_02_peer_close_and_missing_server_retry_until_server_appears() {
        const client = loadProductionClient();
        client.minimumRetryMs = 5;
        client.maximumRetryMs = 20;
        const timerSpy = signalSpy.createObject(testCase, {
            "target": client.reconnectTimer,
            "signalName": "triggered"
        });
        const socketSpy = signalSpy.createObject(testCase, {
            "target": client.testSocket,
            "signalName": "connectedChanged"
        });

        client.enabled = true;
        tryCompare(client.testSocket, "connected", true, 100);
        client.testSocket.connectionStateChanged();

        client.testSocket.connected = false;
        client.testSocket.connectionStateChanged();
        compare(client.reconnectAttempt, 1);
        compare(client.reconnectTimer.interval, 5);
        verify(client.reconnectTimer.running);

        tryCompare(timerSpy, "count", 1, 100);
        compare(client.testSocket.connected, true);

        const expectedDelays = [10, 20, 20];
        for (let failure = 0; failure < expectedDelays.length; ++failure) {
            const attemptsBefore = client.reconnectAttempt;
            client.testSocket.error();
            client.testSocket.error();

            compare(client.testSocket.connected, false, "failure " + failure);
            compare(client.reconnectAttempt, attemptsBefore + 1, "failure " + failure);
            compare(client.reconnectTimer.interval, expectedDelays[failure], "failure " + failure);
            verify(client.reconnectTimer.running, "failure " + failure);
            tryCompare(timerSpy, "count", failure + 2, 100);
            compare(client.testSocket.connected, true, "retry " + failure);
        }

        client.testSocket.connectionStateChanged();
        client.eventAccepted({});
        compare(client.reconnectAttempt, 0);
        verify(!client.reconnectTimer.running);

        for (let restart = 1; restart < 25; ++restart) {
            client.testSocket.connected = false;
            client.testSocket.connectionStateChanged();
            compare(client.reconnectAttempt, 1, "restart " + restart);
            compare(client.reconnectTimer.interval, 5, "restart " + restart);
            tryCompare(timerSpy, "count", restart * 2 + 3, 100);
            compare(client.testSocket.connected, true, "restart attempt " + restart);

            client.testSocket.error();
            client.testSocket.error();
            compare(client.testSocket.connected, false, "restart failure " + restart);
            compare(client.reconnectAttempt, 2, "restart failure " + restart);
            compare(client.reconnectTimer.interval, 10, "restart failure " + restart);
            tryCompare(timerSpy, "count", restart * 2 + 4, 100);
            compare(client.testSocket.connected, true, "restart retry " + restart);

            client.testSocket.connectionStateChanged();
            client.eventAccepted({});
            compare(client.reconnectAttempt, 0, "restart success " + restart);
            verify(!client.reconnectTimer.running, "restart success " + restart);
        }

        compare(timerSpy.count, 52);
        compare(socketSpy.count, 105);

        client.stopStream("clean test disconnect");
        compare(client.testSocket.connected, false);
        verify(!client.reconnectTimer.running);
        const retriesAtStop = timerSpy.count;
        wait(50);
        compare(timerSpy.count, retriesAtStop);
        compare(client.testSocket.connected, false);
    }
}
