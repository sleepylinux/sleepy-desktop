// SPDX-License-Identifier: GPL-3.0-only
// Modified for Sleepy on 2026-08-31: serialized v3 desktop control client.

pragma Singleton

import QtQuick 6.0
import Quickshell.Io

QtObject {
    id: root

    property string controlSocketPath: DesktopClient.controlSocketPath
    property int timeoutMs: 2500
    property string pendingRequestId: ""
    property string queuedLine: ""
    property string status: "idle"
    property string errorString: ""
    property var lastResult: null
    property var observedRequestIds: Object.freeze({})
    property var observedRequestOrder: Object.freeze([])
    readonly property bool busy: pendingRequestId.length > 0

    signal commandCompleted(var result)
    signal commandFailed(string message)
    signal mutationCompleted

    function own(object, key) {
        return object && Object.prototype.hasOwnProperty.call(object, key);
    }

    function uuid() {
        return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, function(c) {
            const v = Math.floor(Math.random() * 16);
            return (c === "x" ? v : (v & 3) | 8).toString(16);
        });
    }

    function canonicalUuid(value) {
        return typeof value === "string"
            && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(value);
    }

    function exact(value, required, optional) {
        if (!value || typeof value !== "object" || Array.isArray(value))
            return false;
        const allowed = required.concat(optional || []);
        const keys = Object.keys(value);
        return required.every(key => keys.indexOf(key) >= 0)
            && keys.every(key => allowed.indexOf(key) >= 0);
    }

    function validFamily(family) {
        return ["system", "compositor", "notification", "launcher",
                "appearance", "utility", "session"].indexOf(family) >= 0;
    }

    function rememberRequest(requestId, generation) {
        const observed = Object.assign({}, root.observedRequestIds);
        let order = root.observedRequestOrder.slice();
        if (!root.own(observed, requestId))
            order.push(requestId);
        observed[requestId] = generation;
        while (order.length > DesktopClient.maximumObservedRequests) {
            const evicted = order.shift();
            delete observed[evicted];
        }
        root.observedRequestIds = Object.freeze(observed);
        root.observedRequestOrder = Object.freeze(order);
    }

    function clearObservedRequests() {
        root.observedRequestIds = Object.freeze({});
        root.observedRequestOrder = Object.freeze([]);
    }

    function send(family, command, requestId) {
        if (root.busy || !root.validFamily(family) || !command
                || typeof command !== "object" || Array.isArray(command)
                || !Number.isSafeInteger(DesktopClient.generation)
                || DesktopClient.generation <= 0)
            return false;
        const id = requestId && requestId.length ? requestId : root.uuid();
        if (!root.canonicalUuid(id))
            return false;
        root.pendingRequestId = id;
        root.status = "loading";
        root.errorString = "";
        root.queuedLine = JSON.stringify({
            "schemaVersion": 3,
            "requestId": id,
            "expectedGeneration": DesktopClient.generation,
            "command": {
                "family": family,
                "command": command
            }
        }) + "\n";
        controlSocket.connected = true;
        if (controlSocket.connected)
            root.flush();
        responseTimeout.restart();
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
        return root.system({"capability": capability, "value": value});
    }

    function flush() {
        if (!controlSocket.connected || !root.queuedLine.length)
            return;
        controlSocket.write(root.queuedLine);
        controlSocket.flush();
        root.queuedLine = "";
    }

    function validResult(result) {
        if (!result || result.schemaVersion !== 3
                || result.requestId !== root.pendingRequestId
                || !Number.isSafeInteger(result.generation) || result.generation <= 0
                || ["succeeded", "failed"].indexOf(result.status) < 0)
            return false;
        if (result.status === "succeeded")
            return root.exact(result, ["schemaVersion", "requestId", "generation", "status"], []);
        return root.exact(result, ["schemaVersion", "requestId", "generation", "status", "diagnostic"], [])
            && root.exact(result.diagnostic, ["message"], [])
            && typeof result.diagnostic.message === "string"
            && result.diagnostic.message.trim().length > 0;
    }

    function acceptResponse(line) {
        let result;
        try {
            result = JSON.parse(String(line));
        } catch (error) {
            return root.fail("Malformed desktop command response");
        }
        if (!root.validResult(result))
            return root.fail("Invalid desktop command response");
        root.lastResult = Object.freeze(Object.assign({}, result));
        root.rememberRequest(result.requestId, result.generation);
        DesktopClient.acceptCommandResult(result);
        root.pendingRequestId = "";
        root.queuedLine = "";
        controlSocket.connected = false;
        responseTimeout.stop();
        if (result.status === "failed")
            return root.fail(result.diagnostic.message);
        root.status = "succeeded";
        root.errorString = "";
        root.commandCompleted(root.lastResult);
        root.mutationCompleted();
        return true;
    }

    function fail(message) {
        root.status = "error";
        root.errorString = message;
        root.pendingRequestId = "";
        root.queuedLine = "";
        responseTimeout.stop();
        controlSocket.connected = false;
        root.commandFailed(message);
        return false;
    }

    readonly property Connections desktopConnections: Connections {
        target: DesktopClient
        function onDaemonGenerationChanged() { root.clearObservedRequests(); }
        function onConnectionStateChanged() {
            if (DesktopClient.connectionState !== "ready")
                root.clearObservedRequests();
        }
    }

    readonly property Socket controlSocket: Socket {
        path: root.controlSocketPath
        parser: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (String(data).trim().length)
                    root.acceptResponse(data);
            }
        }
        onConnectionStateChanged: if (connected) root.flush()
        onError: root.fail("Desktop control service unavailable")
    }

    readonly property Timer responseTimeout: Timer {
        interval: root.timeoutMs
        repeat: false
        onTriggered: root.fail("Desktop command timed out")
    }
}
