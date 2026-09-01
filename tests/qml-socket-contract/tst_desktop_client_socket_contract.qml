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
        const timerSpy = signalSpy.createObject(testCase, {
            "target": client.reconnectTimer,
            "signalName": "triggered"
        });

        initialSocket.peerCloseError();
        compare(initialSocket.connected, true);
        const firstRetry = client.testSocket;
        verify(firstRetry !== initialSocket);
        compare(client.reconnectAttempt, 1);
        compare(client.reconnectTimer.interval, 5);
        verify(client.reconnectTimer.running);
        initialSocket.acknowledgePeerClose();
        compare(initialSocket.connected, false);
        compare(initialSocket.connectAttempts, 1);
        initialSocket.emitConnectionState();
        compare(client.testSocket, firstRetry);

        tryVerify(() => firstRetry.hasTransport, 100);
        compare(firstRetry.connectAttempts, 1);
        compare(timerSpy.count, 1);
        firstRetry.failAttempt();
        const secondRetry = client.testSocket;
        verify(secondRetry !== firstRetry);
        compare(client.reconnectAttempt, 2);
        compare(client.reconnectTimer.interval, 10);
        verify(client.reconnectTimer.running);

        firstRetry.failAttempt();
        compare(client.testSocket, secondRetry);
        tryCompare(secondRetry, "liveInstances", baselineInstances, 100);
        tryVerify(() => secondRetry.hasTransport, 100);
        compare(secondRetry.connectAttempts, 1);
        compare(timerSpy.count, 2);
        secondRetry.succeedAttempt();
        compare(secondRetry.connected, true);
        client.eventAccepted({});
        compare(client.reconnectAttempt, 0);
        verify(!client.reconnectTimer.running);
        client.destroy();
        wait(0);
    }

    function test_disable_only_waits_for_ack_and_stays_idle() {
        const client = loadProductionClient();
        connectClient(client);
        const socket = client.testSocket;
        const baselineInstances = socket.liveInstances;

        client.enabled = false;
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
        client.destroy();
        wait(0);
    }

    function test_disable_enable_before_ack_replays_exactly_one_start() {
        const client = loadProductionClient();
        connectClient(client);
        const socket = client.testSocket;

        client.enabled = false;
        compare(client.intentionalDisconnect, true);
        client.enabled = true;
        wait(0);
        compare(socket.connectAttempts, 1);
        compare(socket.disconnecting, true);

        socket.acknowledgeDisconnect();
        const replacement = client.testSocket;
        verify(replacement !== socket);
        compare(client.intentionalDisconnect, false);
        tryVerify(() => replacement.hasTransport, 100);
        compare(replacement.connectAttempts, 1);
        verify(!client.reconnectTimer.running);
        replacement.succeedAttempt();
        compare(replacement.connected, true);
        client.destroy();
        wait(0);
    }

    function test_repeated_toggles_and_stale_acks_replay_one_current_generation() {
        const client = loadProductionClient();
        connectClient(client);
        const socket = client.testSocket;
        const baselineInstances = socket.liveInstances;

        client.enabled = false;
        client.enabled = true;
        client.enabled = false;
        client.enabled = true;
        wait(0);
        socket.acknowledgeDisconnect();
        const replacement = client.testSocket;
        socket.emitConnectionState();
        socket.emitConnectionState();
        socket.emitError();
        tryVerify(() => replacement.hasTransport, 100);
        compare(client.testSocket, replacement);
        compare(replacement.connectAttempts, 1);
        verify(!client.reconnectTimer.running);
        tryCompare(replacement, "liveInstances", baselineInstances, 100);
        replacement.succeedAttempt();
        client.destroy();
        wait(0);
    }

    function test_missing_server_backoff_is_bounded_and_retires_each_failure() {
        const client = loadProductionClient();
        client.minimumRetryMs = 1;
        client.maximumRetryMs = 4;
        connectClient(client);
        const baselineInstances = client.testSocket.liveInstances;

        const connectedSocket = client.testSocket;
        connectedSocket.peerCloseError();
        connectedSocket.acknowledgePeerClose();
        compare(connectedSocket.connectAttempts, 1);
        for (let failure = 0; failure < 6; ++failure) {
            const failedSocket = client.testSocket;
            tryVerify(() => failedSocket.hasTransport, 100);
            failedSocket.failAttempt();
            failedSocket.failAttempt();
            const replacement = client.testSocket;
            verify(replacement !== failedSocket, "generation " + failure);
            compare(client.reconnectAttempt, failure + 2, "attempt " + failure);
            compare(client.reconnectTimer.interval, Math.min(4, Math.pow(2, failure + 1)),
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
            connectedSocket.peerCloseError();
            compare(client.reconnectAttempt, 1, "peer close " + restart);
            compare(client.reconnectTimer.interval, 1, "first delay " + restart);
            const firstRetry = client.testSocket;
            verify(firstRetry !== connectedSocket, "peer generation " + restart);
            connectedSocket.acknowledgePeerClose();
            compare(connectedSocket.connectAttempts, 1,
                "successful target cleared " + restart);
            connectedSocket.emitConnectionState();
            tryVerify(() => firstRetry.hasTransport, 100);
            compare(firstRetry.connectAttempts, 1, "first retry transport " + restart);

            firstRetry.failAttempt();
            firstRetry.failAttempt();
            const replacement = client.testSocket;
            verify(replacement !== firstRetry, "replacement " + restart);
            compare(client.reconnectAttempt, 2, "failed delayed retry " + restart);
            compare(client.reconnectTimer.interval, 2, "second-loop delay " + restart);
            tryVerify(() => replacement.hasTransport, 100);
            compare(replacement.connectAttempts, 1, "single transport " + restart);
            tryCompare(replacement, "liveInstances", baselineInstances, 100);
            replacement.succeedAttempt();
            client.eventAccepted({});
            compare(client.reconnectAttempt, 0, "accepted " + restart);
            verify(!client.reconnectTimer.running, "timer stopped " + restart);
            compare(timerSpy.count, (restart + 1) * 2, "two sequential retries " + restart);
        }

        client.destroy();
        wait(0);
    }

    function test_repeated_async_disable_enable_replays_without_late_retry() {
        const client = loadProductionClient();
        connectClient(client);

        for (let cycle = 0; cycle < 30; ++cycle) {
            const stoppingSocket = client.testSocket;
            const baselineInstances = stoppingSocket.liveInstances;
            client.enabled = false;
            compare(client.intentionalDisconnect, true, "suppression " + cycle);
            stoppingSocket.emitError();
            stoppingSocket.emitError();
            verify(!client.reconnectTimer.running, "error suppression " + cycle);
            client.enabled = true;
            wait(0);

            stoppingSocket.acknowledgeDisconnect();
            const replacement = client.testSocket;
            compare(client.intentionalDisconnect, false, "ack " + cycle);
            verify(replacement !== stoppingSocket, "retired stop generation " + cycle);
            stoppingSocket.emitError();
            stoppingSocket.emitConnectionState();
            verify(!client.reconnectTimer.running, "late error " + cycle);
            tryCompare(replacement, "liveInstances", baselineInstances, 100);

            tryVerify(() => replacement.hasTransport, 100);
            compare(replacement.connectAttempts, 1, "single restart transport " + cycle);
            replacement.succeedAttempt();
            client.eventAccepted({});
            compare(client.reconnectAttempt, 0, "accepted restart " + cycle);
        }

        client.destroy();
        wait(0);
    }
}
