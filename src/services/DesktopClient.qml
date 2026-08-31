// SPDX-License-Identifier: GPL-3.0-only
// Modified for Sleepy on 2026-08-31: v3 desktop event socket client.

pragma Singleton

import QtQuick 6.0
import Quickshell
import Quickshell.Io

DesktopProtocol {
    id: root

    eventSocketPath: Quickshell.env("XDG_RUNTIME_DIR") + "/sleepy/desktop.sock"
    controlSocketPath: Quickshell.env("XDG_RUNTIME_DIR") + "/sleepy/desktop-control.sock"
    minimumRetryMs: 250
    maximumRetryMs: 10000
    maximumObservedRequests: 64

    property bool enabled: true
    property int reconnectAttempt: 0

    function connectStream() {
        if (!root.enabled || desktopSocket.connected)
            return false;
        root.beginConnection();
        desktopSocket.connected = true;
        return true;
    }

    function stopStream(message) {
        desktopSocket.connected = false;
        root.disconnected(message || "Desktop stream stopped");
        return true;
    }

    function scheduleReconnect(message) {
        root.disconnected(message);
        if (root.enabled) {
            reconnectTimer.interval = root.boundedRetryDelay(root.reconnectAttempt);
            reconnectTimer.restart();
        }
    }

    Component.onCompleted: if (root.enabled) Qt.callLater(root.connectStream)

    onEnabledChanged: {
        if (root.enabled)
            Qt.callLater(root.connectStream);
        else
            root.stopStream("Desktop stream disabled");
    }

    onEventAccepted: root.reconnectAttempt = 0

    readonly property Socket desktopSocket: Socket {
        path: root.eventSocketPath
        parser: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (String(data).trim().length === 0)
                    return;
                if (!root.acceptLine(data))
                    root.desktopSocket.connected = false;
            }
        }
        onConnectionStateChanged: {
            if (connected)
                root.beginConnection();
        }
        onError: {
            root.reconnectAttempt = Math.min(16, root.reconnectAttempt + 1);
            root.scheduleReconnect("Desktop stream unavailable");
        }
    }

    readonly property Timer reconnectTimer: Timer {
        interval: root.minimumRetryMs
        repeat: false
        onTriggered: root.connectStream()
    }
}
