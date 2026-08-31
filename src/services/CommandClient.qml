// SPDX-License-Identifier: GPL-3.0-only
// Modified for Sleepy on 2026-08-31: serialized v3 desktop control client.

pragma Singleton

import QtQuick 6.0
import Quickshell.Io
import "DesktopCommands.js" as DesktopCommands

QtObject {
    id: root

    property string controlSocketPath: DesktopClient.controlSocketPath
    property alias timeoutMs: protocol.timeoutMs
    property alias pendingRequestId: protocol.pendingRequestId
    property alias queuedLine: protocol.queuedLine
    property alias status: protocol.status
    property alias errorString: protocol.errorString
    property alias lastResult: protocol.lastResult
    property alias observedRequestIds: protocol.observedRequestIds
    property alias observedRequestOrder: protocol.observedRequestOrder
    property alias responseTimeout: protocol.responseTimeout
    readonly property bool busy: protocol.busy

    signal commandCompleted(var result)
    signal commandFailed(string message)
    signal mutationCompleted

    function own(object, key) { return protocol.own(object, key); }
    function uuid() { return protocol.uuid(); }
    function canonicalUuid(value) { return protocol.canonicalUuid(value); }
    function exact(value, required, optional) { return protocol.exact(value, required, optional || []); }
    function validFamily(family) { return protocol.validFamily(family); }
    function rememberRequest(requestId, generation) { protocol.rememberRequest(requestId, generation); }
    function clearObservedRequests() { protocol.clearObservedRequests(); }
    function validResult(result) { return protocol.validResult(result); }
    function acceptResponse(line) { return protocol.acceptResponse(line); }

    function fail(message) {
        controlSocket.connected = false;
        return protocol.fail(message);
    }

    function send(family, command, requestId) {
        if (!protocol.send(family, command, requestId || ""))
            return false;
        controlSocket.connected = true;
        if (controlSocket.connected)
            root.flush();
        return true;
    }

    function system(command, requestId) {
        return root.send("system", command, requestId || "");
    }

    function compositor(command, requestId) {
        return root.send("compositor", command, requestId || "");
    }

    function notification(command, requestId) {
        return root.send("notification", command, requestId || "");
    }

    function launcher(command, requestId) {
        return root.send("launcher", command, requestId || "");
    }

    function appearance(command, requestId) {
        return root.send("appearance", command, requestId || "");
    }

    function utility(command, requestId) {
        return root.send("utility", command, requestId || "");
    }

    function session(command, requestId) {
        return root.send("session", command, requestId || "");
    }

    function sendMutation(capability, value) {
        let command = null;
        switch (capability) {
        case "network.enabled":
            command = DesktopCommands.networkSetWifiEnabled(value);
            break;
        case "display.nightLightEnabled":
            command = DesktopCommands.displaySetNightLightEnabled(value);
            break;
        case "power.profile":
            command = DesktopCommands.powerSetProfile(value);
            break;
        default:
            command = null;
        }
        return command ? root.system(command) : false;
    }

    function flush() {
        if (!controlSocket.connected || !protocol.queuedLine.length)
            return;
        controlSocket.write(protocol.queuedLine);
        controlSocket.flush();
        protocol.queuedLine = "";
    }

    DesktopCommandProtocol {
        id: protocol

        generation: DesktopClient.generation
        maximumObservedRequests: DesktopClient.maximumObservedRequests

        onResponseAccepted: result => {
            DesktopClient.acceptCommandResult(result);
            controlSocket.connected = false;
        }
        onCommandCompleted: result => root.commandCompleted(result)
        onCommandFailed: message => root.commandFailed(message)
        onMutationCompleted: root.mutationCompleted()
    }

    readonly property Connections desktopConnections: Connections {
        target: DesktopClient
        function onDaemonGenerationChanged() { protocol.clearObservedRequests(); }
        function onConnectionStateChanged() {
            if (DesktopClient.connectionState !== "ready")
                protocol.clearObservedRequests();
        }
    }

    readonly property Socket controlSocket: Socket {
        path: root.controlSocketPath
        parser: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (String(data).trim().length)
                    protocol.acceptResponse(data);
            }
        }
        onConnectionStateChanged: if (connected) root.flush()
        onError: root.fail("Desktop control service unavailable")
    }
}
