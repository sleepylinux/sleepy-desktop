import QtQuick 6.0
import QtTest 1.0

TestCase {
    id: testCase

    name: "DesktopClientSocketContract"

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
        const client = Qt.createQmlObject(qml, testCase, "ProductionDesktopSocketContractClient");
        verify(client !== null);
        client.minimumRetryMs = 5;
        client.maximumRetryMs = 20;
        return client;
    }

    function connectClient(client) {
        client.enabled = true;
        tryVerify(() => client.testSocket.hasTransport, 100);
        compare(client.testSocket.connectAttempts, 1);
        client.testSocket.succeedAttempt();
        compare(client.testSocket.connected, true);
    }

    function test_failed_retry_replaces_stale_transport_before_server_returns() {
        const client = loadProductionClient();
        connectClient(client);
        const initialSocket = client.testSocket;
        const baselineInstances = initialSocket.liveInstances;

        initialSocket.peerClose();
        compare(initialSocket.connected, false);
        verify(client.reconnectTimer.running);
        tryVerify(() => initialSocket.connectAttempts === 2, 100);
        initialSocket.failAttempt();
        const failedInstance = initialSocket.instanceId;

        verify(client.testSocket.instanceId !== failedInstance);
        const replacement = client.testSocket;
        verify(!replacement.hasTransport);
        verify(client.reconnectTimer.running);

        initialSocket.failAttempt();
        compare(client.testSocket, replacement);
        compare(client.reconnectAttempt, 1);
        tryCompare(replacement, "liveInstances", baselineInstances, 100);
        tryVerify(() => replacement.hasTransport, 100);
        compare(replacement.connectAttempts, 1);
        replacement.succeedAttempt();
        compare(replacement.connected, true);
        client.eventAccepted({});
        compare(client.reconnectAttempt, 0);
        verify(!client.reconnectTimer.running);
        client.destroy();
        wait(0);
    }

    function test_clean_stop_waits_for_async_ack_and_explicit_start_reconnects() {
        const client = loadProductionClient();
        connectClient(client);
        const socket = client.testSocket;
        const baselineInstances = socket.liveInstances;

        client.stopStream("intentional stop");
        compare(client.intentionalDisconnect, true);
        compare(socket.connected, true);
        compare(socket.disconnecting, true);
        verify(!client.reconnectTimer.running);

        socket.acknowledgeDisconnect();
        compare(socket.connected, false);
        compare(client.intentionalDisconnect, false);
        verify(client.testSocket !== socket);
        verify(!client.reconnectTimer.running);
        socket.emitError();
        socket.emitError();
        wait(50);
        verify(!client.reconnectTimer.running);
        compare(client.testSocket.hasTransport, false);
        compare(client.testSocket.liveInstances, baselineInstances);

        verify(client.connectStream());
        const restartedSocket = client.testSocket;
        compare(restartedSocket.hasTransport, true);
        compare(restartedSocket.connectAttempts, 1);
        restartedSocket.succeedAttempt();
        compare(restartedSocket.connected, true);
        client.eventAccepted({});
        compare(client.reconnectAttempt, 0);
        client.destroy();
        wait(0);
    }

    function test_missing_server_backoff_is_bounded_and_retires_each_failure() {
        const client = loadProductionClient();
        client.minimumRetryMs = 1;
        client.maximumRetryMs = 4;
        connectClient(client);
        const baselineInstances = client.testSocket.liveInstances;

        client.testSocket.peerClose();
        for (let failure = 0; failure < 6; ++failure) {
            const failedSocket = client.testSocket;
            tryVerify(() => failedSocket.hasTransport, 100);
            failedSocket.failAttempt();
            failedSocket.failAttempt();
            const replacement = client.testSocket;
            verify(replacement !== failedSocket, "generation " + failure);
            compare(client.reconnectAttempt, failure + 1, "attempt " + failure);
            compare(client.reconnectTimer.interval, Math.min(4, Math.pow(2, failure)),
                "bounded delay " + failure);
            tryCompare(replacement, "liveInstances", baselineInstances, 100);
        }

        tryVerify(() => client.testSocket.hasTransport, 100);
        client.testSocket.succeedAttempt();
        client.eventAccepted({});
        compare(client.reconnectAttempt, 0);
        client.destroy();
        wait(0);
    }

    function test_repeated_restarts_keep_one_bounded_retry_loop() {
        const client = loadProductionClient();
        client.minimumRetryMs = 1;
        client.maximumRetryMs = 4;
        connectClient(client);
        const timerSpy = signalSpy.createObject(testCase, {
            "target": client.reconnectTimer,
            "signalName": "triggered"
        });

        for (let restart = 0; restart < 40; ++restart) {
            const connectedSocket = client.testSocket;
            const baselineInstances = connectedSocket.liveInstances;
            connectedSocket.peerClose();
            compare(client.reconnectAttempt, 1, "peer close " + restart);
            compare(client.reconnectTimer.interval, 1, "first delay " + restart);
            tryVerify(() => connectedSocket.connectAttempts === 2, 100);

            connectedSocket.failAttempt();
            connectedSocket.failAttempt();
            const replacement = client.testSocket;
            verify(replacement !== connectedSocket, "replacement " + restart);
            compare(client.reconnectAttempt, 1, "failed automatic retry " + restart);
            compare(client.reconnectTimer.interval, 1, "single-loop delay " + restart);
            tryVerify(() => replacement.hasTransport, 100);
            compare(replacement.connectAttempts, 1, "single transport " + restart);
            tryCompare(replacement, "liveInstances", baselineInstances, 100);
            replacement.succeedAttempt();
            client.eventAccepted({});
            compare(client.reconnectAttempt, 0, "accepted " + restart);
            verify(!client.reconnectTimer.running, "timer stopped " + restart);
            compare(timerSpy.count, restart + 1, "one loop " + restart);
        }

        client.destroy();
        wait(0);
    }

    function test_repeated_async_stop_start_has_no_late_retry() {
        const client = loadProductionClient();
        connectClient(client);

        for (let cycle = 0; cycle < 30; ++cycle) {
            const stoppingSocket = client.testSocket;
            const baselineInstances = stoppingSocket.liveInstances;
            client.stopStream("cycle " + cycle);
            compare(client.intentionalDisconnect, true, "suppression " + cycle);
            stoppingSocket.emitError();
            stoppingSocket.emitError();
            verify(!client.reconnectTimer.running, "error suppression " + cycle);

            stoppingSocket.acknowledgeDisconnect();
            const replacement = client.testSocket;
            compare(client.intentionalDisconnect, false, "ack " + cycle);
            verify(replacement !== stoppingSocket, "retired stop generation " + cycle);
            stoppingSocket.emitError();
            verify(!client.reconnectTimer.running, "late error " + cycle);
            tryCompare(replacement, "liveInstances", baselineInstances, 100);

            verify(client.connectStream(), "explicit start " + cycle);
            compare(replacement.connectAttempts, 1, "single restart transport " + cycle);
            replacement.succeedAttempt();
            client.eventAccepted({});
            compare(client.reconnectAttempt, 0, "accepted restart " + cycle);
        }

        client.destroy();
        wait(0);
    }
}
