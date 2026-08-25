// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0
import Quickshell.Io

ThemeProtocol {
    id: root
    property string runtimeDirectory: Quickshell.env("XDG_RUNTIME_DIR")
    readonly property string socketPath: runtimeDirectory + "/sleepy/theme.sock"
    property string queuedLine: ""
    property bool startupComplete: false
    signal applyCandidateToUi(var theme)

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
        themeSocket.connected = false;
    }
    Component.onCompleted: Qt.callLater(function() { root.send(root.get()); })
    onCandidateReceived: theme => {
        root.applyCandidateToUi(theme);
        const ack = root.acknowledgement(true);
        if (!ack) { root.fail("Theme candidate could not be acknowledged"); return; }
        themeSocket.write(JSON.stringify(ack) + "\n"); themeSocket.flush();
    }
    onRollbackRequested: theme => root.applyCandidateToUi(theme)
    onResultReceived: resultStatus => {
        responseTimeout.stop();
        root.startupComplete = true;
        if (resultStatus === "confirmed" || resultStatus === "reconciled")
            root.mutationsEnabled = true;
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
}
