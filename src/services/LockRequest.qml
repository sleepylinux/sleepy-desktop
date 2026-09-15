// SPDX-License-Identifier: GPL-3.0-only
// A single idempotent lock intent may wait for reconnect, never other mutations.
import QtQuick 6.0

QtObject {
    id: root
    required property var protocol
    property bool ready: false
    property var generation: 0
    // Bounds the entire intent, including snapshot wait and the one stale retry.
    // The existing control transport keeps its own shorter response timeout.
    property int timeoutMs: 10000
    property bool pending: false
    property string errorString: ""
    property bool awaitingReply: false
    property bool retried: false
    property bool suppressFailure: false
    property var minimumGeneration: 0
    property string requestId: ""
    signal dispatchNeeded
    signal failed(string message)

    function request(id) {
        // Explicit-ID callers use the unchanged one-shot command protocol.
        if (id)
            return false;
        if (root.pending)
            return true;
        root.errorString = "";
        root.retried = false;
        root.minimumGeneration = 0;
        root.requestId = root.protocol.uuid();
        root.pending = true;
        deadline.restart();
        root.attempt();
        return true;
    }

    function attempt() {
        if (!root.pending || root.awaitingReply || !root.ready || root.protocol.busy
                || !Number.isSafeInteger(root.generation) || root.generation <= 0
                || root.generation < root.minimumGeneration)
            return;
        if (!root.protocol.send("session", "lock", root.requestId)) {
            root.finish("Lock request could not be submitted");
            return;
        }
        root.awaitingReply = true;
        root.dispatchNeeded();
    }

    function finish(message) {
        deadline.stop();
        root.pending = false;
        root.awaitingReply = false;
        root.requestId = "";
        root.errorString = message || "";
        if (message)
            root.failed(message);
    }

    function handleResult(result) {
        if (!root.pending || result.requestId !== root.requestId)
            return false;
        root.awaitingReply = false;
        if (result.status === "succeeded") {
            root.finish("");
        } else {
            // Protocol emits commandFailed after responseAccepted. Consume that
            // same failure once; do not expose a recovered stale response as final.
            root.suppressFailure = true;
            const message = result.diagnostic.message;
            if (message === "request.generation-stale" && !root.retried) {
                root.retried = true;
                root.minimumGeneration = result.generation;
                root.requestId = root.protocol.uuid();
                Qt.callLater(root.attempt);
            } else {
                root.finish(message);
            }
        }
        return true;
    }

    function handleFailure(message) {
        if (root.suppressFailure) {
            root.suppressFailure = false;
            return true;
        }
        if (!root.pending || !root.awaitingReply)
            return false;
        // Transport errors and timeouts are ambiguous: never replay them.
        root.finish(message);
        return true;
    }

    onReadyChanged: Qt.callLater(root.attempt)
    onGenerationChanged: Qt.callLater(root.attempt)
    readonly property Connections protocolState: Connections {
        target: root.protocol
        function onBusyChanged() { Qt.callLater(root.attempt); }
    }
    readonly property Timer deadline: Timer {
        interval: root.timeoutMs
        onTriggered: {
            if (root.awaitingReply)
                root.protocol.fail("Lock request timed out");
            else
                root.finish("Lock unavailable: sleepy-sessiond did not become ready");
        }
    }
}
