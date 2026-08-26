// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0
import Quickshell
import Quickshell.Io

ThemeProtocol {
    id: root
    property string runtimeDirectory: Quickshell.env("XDG_RUNTIME_DIR")
    readonly property string socketPath: runtimeDirectory + "/sleepy/theme.sock"
    property string queuedLine: ""
    property bool startupComplete: false
    property var candidateApplier: null
    property bool loadingCatalog: false

    function send(request) {
        if (!request) return false;
        root.queuedLine = JSON.stringify(request) + "\n";
        themeSocket.connected = true;
        if (themeSocket.connected) flush();
        responseTimeout.restart();
        return true;
    }
    function flush() {
        if (!themeSocket.connected || root.queuedLine.length === 0) return;
        themeSocket.write(root.queuedLine); themeSocket.flush(); root.queuedLine = "";
    }
    function fail(message) {
        responseTimeout.stop(); root.status = "unavailable"; root.errorString = message;
        root.pendingRequestId = ""; root.queuedLine = ""; root.mutationsEnabled = false;
        root.startupComplete = false;
        themeSocket.connected = false;
        reconnectBackoff.fail();
        reconnectTimer.restart();
    }
    Component.onCompleted: Qt.callLater(function() { root.send(root.get()); })
    onCandidateReceived: theme => {
        let accepted = false;
        try {
            accepted = typeof root.candidateApplier === "function"
                && root.candidateApplier(theme) === true;
        } catch (error) { accepted = false; }
        const ack = root.acknowledgement(accepted);
        if (!ack) { root.fail("Theme candidate could not be acknowledged"); return; }
        themeSocket.write(JSON.stringify(ack) + "\n"); themeSocket.flush();
    }
    onRollbackRequested: theme => {
        if (typeof root.candidateApplier === "function") root.candidateApplier(theme);
    }
    onResultReceived: resultStatus => {
        responseTimeout.stop();
        const success = resultStatus === "confirmed" || resultStatus === "reconciled";
        if (success
                && root.lastCompletedOperation === "get" && !root.loadingCatalog) {
            root.loadingCatalog = true;
            Qt.callLater(function() { root.send(root.list()); });
            return;
        }
        root.loadingCatalog = false;
        if (success) {
            root.startupComplete = true;
            reconnectBackoff.succeed();
            reconnectTimer.stop();
            root.mutationsEnabled = true;
        } else {
            root.startupComplete = false;
            reconnectBackoff.fail();
            reconnectTimer.restart();
        }
        themeSocket.connected = false;
    }
    readonly property Socket themeSocket: Socket {
        path: root.socketPath
        parser: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (String(data).trim().length > 0 && !root.acceptLine(data))
                    root.fail(root.errorString || "Theme protocol failed");
            }
        }
        onConnectionStateChanged: if (connected) root.flush()
        onError: root.fail("Theme service unavailable")
    }
    readonly property Timer responseTimeout: Timer {
        interval: 2500
        onTriggered: root.fail("Theme acknowledgement timed out")
    }
    readonly property ReconnectBackoff reconnectBackoff: ReconnectBackoff {}
    readonly property Timer reconnectTimer: Timer {
        interval: root.reconnectBackoff.delayMs
        repeat: false
        onTriggered: if (!root.startupComplete && !root.pendingRequestId) root.send(root.get())
    }
}
