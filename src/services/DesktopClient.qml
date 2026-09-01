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
    property alias reconnectAttempt: reconnectPolicy.reconnectAttempt
    property alias intentionalDisconnect: reconnectPolicy.intentionalDisconnect
    property alias reconnectTimer: reconnectPolicy.reconnectTimer

    function connectStream() {
        if (!root.enabled || desktopSocket.connected)
            return false;
        reconnectPolicy.reconnectTimer.stop();
        root.beginConnection();
        desktopSocket.connected = true;
        return true;
    }

    function stopStream(message) {
        reconnectPolicy.intentionalDisconnect = true;
        reconnectPolicy.reconnectTimer.stop();
        desktopSocket.connected = false;
        root.disconnected(message || "Desktop stream stopped");
        reconnectPolicy.intentionalDisconnect = false;
        return true;
    }

    function scheduleReconnect(message, countAttempt) {
        return reconnectPolicy.scheduleReconnect(message, countAttempt);
    }

    function handleSocketDisconnected(message) {
        return reconnectPolicy.handleSocketDisconnected(message);
    }

    Component.onCompleted: if (root.enabled) Qt.callLater(root.connectStream)

    onEnabledChanged: {
        if (root.enabled)
            Qt.callLater(root.connectStream);
        else
            root.stopStream("Desktop stream disabled");
    }

    onEventAccepted: root.reconnectAttempt = 0

    readonly property DesktopReconnectPolicy reconnectPolicy: DesktopReconnectPolicy {
        id: reconnectPolicy

        enabled: root.enabled
        minimumRetryMs: root.minimumRetryMs
        maximumRetryMs: root.maximumRetryMs

        onDisconnected: message => root.disconnected(message)
        onReconnectDue: root.connectStream()
    }

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
            if (connected) {
                root.beginConnection();
            } else {
                root.handleSocketDisconnected("Desktop stream disconnected");
            }
        }
        onError: {
            root.scheduleReconnect("Desktop stream unavailable", true);
        }
    }

}
