// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0
import Quickshell
import Quickshell.Io

NotificationCenterModel {
    id: root
    property var events: null
    property string runtimeDirectory: Quickshell.env("XDG_RUNTIME_DIR")
    property string pendingRequestId: ""
    property string queuedLine: ""
    property string status: "offline"
    property string errorString: ""
    function uuid() { return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, function(c) { const v = Math.floor(Math.random() * 16); return (c === "x" ? v : (v & 3) | 8).toString(16); }); }
    function request(type, data) {
        if (root.pendingRequestId) return false;
        root.pendingRequestId = root.uuid(); root.status = "loading";
        root.queuedLine = JSON.stringify({"schemaVersion":2,"requestId":root.pendingRequestId,
            "operation":data === undefined ? {"type":type} : {"type":type,"data":data}}) + "\n";
        socket.connected = true; if (socket.connected) flush(); timeout.restart(); return true;
    }
    function refresh() { return root.request("snapshot"); }
    function dismiss(id) { return root.request("dismiss", {"id":id}); }
    function archiveItem(id) { return root.request("archive", {"id":id}); }
    function markRead(id) { return root.request("markRead", {"id":id}); }
    function setDnd(enabled) { return root.request("setDnd", {"enabled":Boolean(enabled)}); }
    function invokeAction(id, actionId) { return root.request("invokeAction", {"id":id,"actionId":actionId}); }
    function flush() { if (socket.connected && root.queuedLine) { socket.write(root.queuedLine); socket.flush(); root.queuedLine = ""; } }
    function acceptLine(line) {
        let value; try { value = JSON.parse(String(line)); } catch (error) { return fail("Malformed notification response"); }
        const keys = Object.keys(value || {}).sort().join(",");
        if (!value || value.schemaVersion !== 2 || value.requestId !== root.pendingRequestId
                || (keys !== "data,requestId,schemaVersion,status" && keys !== "error,requestId,schemaVersion,status")
                || ["confirmed","error"].indexOf(value.status) < 0) return fail("Invalid notification response");
        if (value.status === "error") {
            if (!value.error || Object.keys(value.error).sort().join(",") !== "code,message"
                    || typeof value.error.code !== "string" || !value.error.code.length
                    || typeof value.error.message !== "string" || !value.error.message.length)
                return fail("Invalid notification error");
            return fail(value.error.code === "expired" ? "Notification action expired" : value.error.message);
        }
        if (!value.data || Object.keys(value.data).sort().join(",") !== "data,type"
                || ["snapshot","actionInvoked"].indexOf(value.data.type) < 0) return fail("Invalid notification response data");
        if (value.data.type === "snapshot" && !root.acceptSnapshot(value.data.data)) return fail("Invalid notification snapshot");
        if (value.data.type === "actionInvoked"
                && (!value.data.data || Object.keys(value.data.data).sort().join(",") !== "actionId,id"
                    || !Number.isSafeInteger(value.data.data.id) || value.data.data.id <= 0
                    || typeof value.data.data.actionId !== "string" || !value.data.data.actionId.length))
            return fail("Invalid notification action confirmation");
        root.status = "ready"; root.errorString = ""; root.pendingRequestId = ""; socket.connected = false; return true;
    }
    function fail(message) { root.status = "error"; root.errorString = message; root.pendingRequestId = ""; socket.connected = false; return false; }
    readonly property Connections eventConnection: Connections {
        target: root.events; enabled: root.events !== null
        function onEventAccepted(envelope) {
            if (envelope.payload.type === "notification" && root.acceptEvent(envelope.payload.data)) Qt.callLater(root.refresh);
            if (envelope.payload.type === "provider" && envelope.payload.data.providerId.indexOf("org.freedesktop.Notifications") === 0) Qt.callLater(root.refresh);
        }
        function onConnectionStateChanged() { if (root.events.connectionState === "ready") Qt.callLater(root.refresh); }
    }
    Component.onCompleted: Qt.callLater(root.refresh)
    readonly property Socket socket: Socket {
        path: root.runtimeDirectory + "/sleepy/notification.sock"
        parser: SplitParser { splitMarker: "\n"; onRead: data => { if (String(data).trim()) root.acceptLine(data); } }
        onConnectionStateChanged: if (connected) root.flush()
        onError: root.fail("Notification service unavailable")
    }
    readonly property Timer timeout: Timer { interval: 2500; onTriggered: root.fail("Notification request timed out") }
}
