// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0
import Quickshell
import Quickshell.Io

ControlProtocol {
    id: root
    property var events: null
    property string runtimeDirectory: Quickshell.env("XDG_RUNTIME_DIR")
    property string queuedLine: ""
    readonly property alias observed: observedCacheObject.observed
    readonly property alias observedOrder: observedCacheObject.order
    signal mutationCompleted
    readonly property ClientRequestLifecycle lifecycle: ClientRequestLifecycle {
        onTimedOut: root.fail("Control request timed out")
    }

    function sendMutation(capability, value) {
        if (!root.events || root.events.connectionState !== "ready") return false;
        const request = root.mutation(capability, value, root.events.generation);
        if (!request) return false;
        if (!root.lifecycle.begin()) return false;
        root.queuedLine = JSON.stringify(request) + "\n"; socket.connected = true;
        if (socket.connected) flush(); return true;
    }
    function flush() { if (socket.connected && root.queuedLine) { socket.write(root.queuedLine); socket.flush(); root.queuedLine = ""; } }
    function maybeComplete(requestId, generation) {
        if (root.pendingRequestId === requestId && root.responseGeneration === generation
                && observedCache.peek(requestId) === generation) {
            observedCache.take(requestId);
            root.complete(); root.mutationCompleted(); socket.connected = false;
        }
    }
    onConfirmed: (requestId, generation) => root.maybeComplete(requestId, generation)
    onStatusChanged: if (status === "confirmed" || status === "error") root.lifecycle.finish()
    readonly property Connections eventConnection: Connections {
        target: root.events
        enabled: root.events !== null
        function onEventAccepted(envelope) {
            if (envelope.cause.kind !== "request") return;
            observedCache.remember(envelope.cause.requestId, envelope.generation);
            root.maybeComplete(envelope.cause.requestId, envelope.generation);
        }
        function onConnectionStateChanged() {
            if (root.events.connectionState !== "ready") observedCache.clear();
        }
    }
    readonly property ObservedRequestCache observedCache: ObservedRequestCache {
        id: observedCacheObject
    }
    readonly property Socket socket: Socket {
        path: root.runtimeDirectory + "/sleepy/control.sock"
        parser: SplitParser { splitMarker: "\n"; onRead: data => { if (String(data).trim()) root.acceptResponse(data); } }
        onConnectionStateChanged: if (connected) root.flush()
        onError: root.fail("Control service unavailable")
    }
}
