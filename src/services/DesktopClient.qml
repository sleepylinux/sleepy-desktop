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
        const socket = root.desktopSocket;
        if (!root.enabled || root.intentionalDisconnect || !socket || socket.connected)
            return false;
        reconnectPolicy.reconnectTimer.stop();
        root.beginConnection();
        socket.connected = true;
        return true;
    }

    function stopStream(message) {
        reconnectPolicy.intentionalDisconnect = true;
        reconnectPolicy.reconnectTimer.stop();
        const socket = root.desktopSocket;
        if (socket && socket.connected) {
            socket.connected = false;
        } else {
            if (root.replaceDesktopSocket(socket))
                reconnectPolicy.intentionalDisconnect = false;
        }
        root.disconnected(message || "Desktop stream stopped");
        return true;
    }

    function scheduleReconnect(message, countAttempt) {
        return reconnectPolicy.scheduleReconnect(message, countAttempt);
    }

    function handleSocketDisconnected(socket, message) {
        if (socket !== root.desktopSocket)
            return false;
        const intentional = root.intentionalDisconnect;
        const result = reconnectPolicy.handleSocketDisconnected(message);
        if (intentional) {
            const replaced = root.replaceDesktopSocket(socket);
            if (replaced && root.enabled)
                Qt.callLater(root.connectStream);
        }
        return result;
    }

    function handleSocketError(socket) {
        if (socket !== root.desktopSocket || root.intentionalDisconnect)
            return false;
        if (!root.replaceDesktopSocket(socket))
            return false;
        return root.scheduleReconnect("Desktop stream unavailable", true);
    }

    function replaceDesktopSocket(expectedSocket) {
        if (expectedSocket && expectedSocket !== root.desktopSocket)
            return false;
        const previousSocket = root.desktopSocket;
        const replacement = desktopSocketFactory.createObject(root);
        if (!replacement)
            return false;
        desktopSocketState.current = replacement;
        if (previousSocket)
            previousSocket.destroy();
        return true;
    }

    Component.onCompleted: {
        root.replaceDesktopSocket(null);
        if (root.enabled)
            Qt.callLater(root.connectStream);
    }

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

    readonly property QtObject desktopSocketState: QtObject {
        property Socket current: null
    }
    readonly property Socket desktopSocket: desktopSocketState.current

    readonly property Component desktopSocketFactory: Component {
        Socket {
            id: socket

            path: root.eventSocketPath
            parser: SplitParser {
                splitMarker: "\n"
                onRead: data => {
                    if (String(data).trim().length === 0)
                        return;
                    if (!root.acceptLine(data))
                        socket.connected = false;
                }
            }
            onConnectionStateChanged: {
                if (socket !== root.desktopSocket)
                    return;
                if (connected) {
                    root.beginConnection();
                } else {
                    root.handleSocketDisconnected(socket, "Desktop stream disconnected");
                }
            }
            onError: root.handleSocketError(socket)
        }
    }

}
