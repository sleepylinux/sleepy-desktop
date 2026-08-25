// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0
import Quickshell.Io

OsdStreamModel {
    id: root
    property string runtimeDirectory: Quickshell.env("XDG_RUNTIME_DIR")
    readonly property string socketPath: runtimeDirectory + "/sleepy/osd.sock"
    property int reconnectAttempt: 0
    readonly property int reconnectDelayMs: Math.min(10000, 250 * Math.pow(2, reconnectAttempt))
    function connectStream() {
        root.beginConnection();
        osdSocket.connected = true;
    }
    Component.onCompleted: root.connectStream()

    readonly property Socket osdSocket: Socket {
        path: root.socketPath
        parser: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (String(data).trim().length === 0) return;
                if (root.acceptLine(data)) root.reconnectAttempt = 0;
                else root.osdSocket.connected = false;
            }
        }
        onConnectionStateChanged: {
            if (!connected) {
                root.disconnected("OSD service disconnected");
                root.reconnectAttempt = Math.min(6, root.reconnectAttempt + 1);
                root.reconnectTimer.restart();
            }
        }
        onError: {
            root.disconnected("OSD service unavailable");
        }
    }
    readonly property Timer reconnectTimer: Timer {
        interval: root.reconnectDelayMs
        onTriggered: root.connectStream()
    }
}
