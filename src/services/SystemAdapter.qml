// SPDX-License-Identifier: GPL-3.0-only
// Modified for Sleepy on 2026-08-31: production state comes from desktop.sock.

import QtQuick 6.0
import "DesktopCommands.js" as DesktopCommands

SystemAdapterCore {
    id: root

    property bool loadOnStartup: true
    property bool refreshAfterCurrent: false
    property var eventSource: DesktopClient
    property var controlClient: CommandClient

    function refresh() {
        if (!root.eventSource || !root.eventSource.snapshotReceived) {
            root.available = false;
            root.diagnostic = root.eventSource ? root.eventSource.diagnostic
                                               : "Desktop event stream unavailable";
            return false;
        }
        return root.acceptRuntimeEvents(root.eventSource);
    }

    function requestImmediateRefresh() {
        if (root.busy) {
            root.refreshAfterCurrent = true;
            return;
        }
        root.refresh();
    }

    function mutate(capability, value) {
        if (!root.controlClient)
            return false;
        const sent = root.controlClient.sendMutation(capability, value);
        if (sent)
            root.mutationCapabilityBusy = capability;
        return sent;
    }

    function perform(action, confirmation) {
        if (confirmation !== "confirmed")
            return false;
        const command = DesktopCommands.session(action);
        return Boolean(root.controlClient && command
                       && root.controlClient.send("session", command));
    }

    Component.onCompleted: {
        root.runtimeStreamRequired = true;
        root.runtimeStreamReady = root.eventSource.connectionState === "ready";
        if (root.loadOnStartup)
            Qt.callLater(root.refresh);
    }

    readonly property Connections eventConnections: Connections {
        target: root.eventSource
        function onEventAccepted() {
            root.runtimeStreamReady = root.eventSource.connectionState === "ready";
            root.refresh();
            if (root.refreshAfterCurrent)
                root.refreshAfterCurrent = false;
        }
        function onConnectionStateChanged() {
            root.runtimeStreamReady = root.eventSource.connectionState === "ready";
            if (!root.runtimeStreamReady) {
                root.available = false;
                root.diagnostic = root.eventSource.diagnostic || "Desktop event stream unavailable";
            }
        }
    }

    readonly property Connections commandConnections: Connections {
        target: root.controlClient
        function onMutationCompleted() {
            root.mutationCapabilityBusy = "";
        }
        function onCommandFailed(message) {
            root.mutationCapabilityBusy = "";
            root.diagnostic = message;
        }
    }
}
