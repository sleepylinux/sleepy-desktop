// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0
import Quickshell.Io

DailyProtocol {
    id: root
    property string runtimeDirectory: Quickshell.env("XDG_RUNTIME_DIR")
    readonly property string socketPath: runtimeDirectory + "/sleepy/daily.sock"
    property bool requestQueued: false
    property string queuedLine: ""

    function sendRequest(request) {
        if (!request || root.pendingRequestId.length === 0) return false;
        root.queuedLine = JSON.stringify(request) + "\n";
        root.requestQueued = true;
        dailySocket.connected = true;
        if (dailySocket.connected) flushRequest();
        return true;
    }
    function flushRequest() {
        if (!root.requestQueued || !dailySocket.connected) return;
        dailySocket.write(root.queuedLine);
        dailySocket.flush();
        root.requestQueued = false;
        root.queuedLine = "";
        responseTimeout.restart();
    }
    function failRequest(message) {
        root.status = "offline"; root.errorString = message;
        root.pendingRequestId = ""; root.requestQueued = false; root.queuedLine = "";
        dailySocket.connected = false;
    }
    readonly property Socket dailySocket: Socket {
        path: root.socketPath
        parser: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (String(data).trim().length === 0) return;
                root.responseTimeout.stop();
                root.acceptResponse(data);
                root.dailySocket.connected = false;
            }
        }
        onConnectionStateChanged: if (connected) root.flushRequest()
        onError: root.failRequest("Daily service unavailable")
    }
    readonly property Timer responseTimeout: Timer {
        interval: 2500
        onTriggered: root.failRequest("Daily request timed out")
    }
}
