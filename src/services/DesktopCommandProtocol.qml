// SPDX-License-Identifier: GPL-3.0-only
// Modified for Sleepy on 2026-08-31: instantiable v3 desktop command protocol core.

import QtQuick 6.0
import "DesktopCommands.js" as DesktopCommands

QtObject {
    id: root

    property int timeoutMs: 2500
    property var generation: 0
    property int maximumObservedRequests: 64
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
    signal responseAccepted(var result)

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
        return DesktopCommands.validFamily(family);
    }

    function rememberRequest(requestId, acceptedGeneration) {
        const observed = Object.assign({}, root.observedRequestIds);
        let order = root.observedRequestOrder.slice();
        if (!root.own(observed, requestId))
            order.push(requestId);
        observed[requestId] = acceptedGeneration;
        while (order.length > root.maximumObservedRequests) {
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
        const commandIsObject = command && typeof command === "object" && !Array.isArray(command);
        const commandIsSessionEnum = family === "session"
            && typeof command === "string" && command.length > 0;
        if (root.busy || !root.validFamily(family) || !command
                || !(commandIsObject || commandIsSessionEnum)
                || !DesktopCommands.validCommand(family, command)
                || !Number.isSafeInteger(root.generation)
                || root.generation <= 0)
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
            "expectedGeneration": root.generation,
            "command": {
                "family": family,
                "command": command
            }
        }) + "\n";
        responseTimeout.restart();
        return true;
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
        root.pendingRequestId = "";
        root.queuedLine = "";
        responseTimeout.stop();
        root.responseAccepted(root.lastResult);
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
        root.commandFailed(message);
        return false;
    }

    readonly property Timer responseTimeout: Timer {
        interval: root.timeoutMs
        repeat: false
        onTriggered: root.fail("Desktop command timed out")
    }
}
