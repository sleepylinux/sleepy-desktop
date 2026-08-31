// SPDX-License-Identifier: GPL-3.0-only
// Modified for Sleepy on 2026-08-31: compatibility facade over DesktopClient.

import QtQuick 6.0

SessionEventModel {
    id: root

    property bool enabled: true
    property var desktopClient: DesktopClient

    function connectStream() {
        root.enabled = true;
        return root.desktopClient.connectStream();
    }

    function stopStream() {
        root.enabled = false;
        return root.desktopClient.stopStream("Desktop stream disabled");
    }

    function syncFromDesktop() {
        root.connectionState = root.desktopClient.connectionState;
        root.diagnostic = root.desktopClient.diagnostic;
        root.generation = root.desktopClient.generation;
        root.snapshotReceived = root.desktopClient.snapshotReceived;
    }

    Component.onCompleted: root.syncFromDesktop()

    readonly property Connections desktopConnections: Connections {
        target: root.desktopClient
        function onEventAccepted(envelope) {
            root.syncFromDesktop();
            root.eventAccepted(envelope);
        }
        function onConnectionStateChanged() {
            root.syncFromDesktop();
        }
        function onProtocolError(message) {
            root.syncFromDesktop();
            root.protocolError(message);
        }
    }
}
