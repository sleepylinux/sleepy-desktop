// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0

QtObject {
    id: root

    property string connectionState: "disconnected"
    property string diagnostic: "Waiting for sleepy-sessiond"
    property double generation: 0
    property string focusedOutputId: ""
    property var capabilities: Object.freeze({})
    property var notifications: Object.freeze([])
    property var providerStates: Object.freeze({})
    property var lastThemeEvent: null
    property string lifecycleState: ""
    property bool snapshotReceived: false

    signal eventAccepted(var envelope)
    signal protocolError(string message)

    readonly property var availabilityStates: Object.freeze([
        "available", "unavailable", "unsupported", "permissionDenied",
        "timeout", "parse", "error"
    ])
    readonly property var capabilityIds: Object.freeze([
        "network", "bluetooth", "audio", "battery", "brightness", "powerProfile",
        "media", "nightLight", "niri", "resources"
    ])

    function canonicalUuid(value) {
        return typeof value === "string"
            && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(value);
    }

    function exactKeys(value, required, optional) {
        if (!value || typeof value !== "object" || Array.isArray(value))
            return false;
        const allowed = required.concat(optional || []);
        const keys = Object.keys(value);
        return required.every(function(key) { return keys.indexOf(key) >= 0; })
            && keys.every(function(key) { return allowed.indexOf(key) >= 0; });
    }

    function beginConnection() {
        root.connectionState = "connecting";
        root.diagnostic = "Waiting for full snapshot";
        root.snapshotReceived = false;
    }

    function disconnected(message) {
        root.connectionState = "offline";
        root.snapshotReceived = false;
        root.diagnostic = message || "sleepy-sessiond disconnected";
    }

    function fail(message) {
        root.connectionState = "error";
        root.diagnostic = message;
        root.protocolError(message);
        return false;
    }

    function normalizedCapability(record) {
        if (!root.exactKeys(record, ["id", "status"], ["value", "diagnostic"])
                || root.capabilityIds.indexOf(record.id) < 0
                || root.availabilityStates.indexOf(record.status) < 0)
            return null;
        if ((record.status === "available" && record.value === undefined)
                || (record.status !== "available" && (record.value !== undefined
                    || !root.exactKeys(record.diagnostic, ["message"], [])
                    || !root.unpadded(record.diagnostic.message))))
            return null;
        if (record.status === "available"
                && (record.diagnostic !== undefined
                    || !root.validCapabilityValue(record.id, record.value)))
            return null;
        return Object.freeze({
            "id": record.id,
            "status": record.status,
            "available": record.status === "available",
            "value": record.value === undefined ? null : record.value,
            "diagnostic": record.diagnostic && typeof record.diagnostic.message === "string"
                          ? record.diagnostic.message : ""
        });
    }

    function unpadded(value) {
        return typeof value === "string" && value.length > 0 && value.trim() === value;
    }

    function finite(value) { return typeof value === "number" && Number.isFinite(value); }
    function normalized(value) { return root.finite(value) && value >= 0 && value <= 1; }
    function uniqueStrings(values) {
        return Array.isArray(values) && values.every(function(value, index) {
            return root.unpadded(value) && values.indexOf(value) === index;
        });
    }
    function uniquePositiveIntegers(values) {
        return Array.isArray(values) && values.every(function(value, index) {
            return Number.isSafeInteger(value) && value > 0 && values.indexOf(value) === index;
        });
    }
    function validCapabilityValue(id, value) {
        if (!root.exactKeys(value, ["type", "data"], []) || value.type !== id
                || !value.data || typeof value.data !== "object" || Array.isArray(value.data))
            return false;
        const data = value.data;
        switch (id) {
        case "network":
            return root.exactKeys(data, ["wifiEnabled", "ethernetConnected", "connectivity"],
                                  ["activeConnectionId"])
                && typeof data.wifiEnabled === "boolean"
                && typeof data.ethernetConnected === "boolean"
                && ["unknown", "none", "portal", "limited", "full"].indexOf(data.connectivity) >= 0
                && (data.activeConnectionId === undefined || root.unpadded(data.activeConnectionId));
        case "bluetooth":
            return root.exactKeys(data, ["powered", "connectedDeviceIds"], [])
                && typeof data.powered === "boolean" && root.uniqueStrings(data.connectedDeviceIds);
        case "audio":
            return root.exactKeys(data, ["outputLevel", "outputMuted", "inputLevel", "inputMuted"],
                                  ["defaultOutputId"])
                && root.normalized(data.outputLevel) && root.normalized(data.inputLevel)
                && typeof data.outputMuted === "boolean" && typeof data.inputMuted === "boolean"
                && (data.defaultOutputId === undefined || root.unpadded(data.defaultOutputId));
        case "battery":
            return root.exactKeys(data, ["percentage", "charging"], ["secondsRemaining"])
                && Number.isSafeInteger(data.percentage) && data.percentage >= 0
                && data.percentage <= 100 && typeof data.charging === "boolean"
                && (data.secondsRemaining === undefined
                    || (Number.isSafeInteger(data.secondsRemaining) && data.secondsRemaining >= 0));
        case "brightness":
            return root.exactKeys(data, ["level"], []) && root.normalized(data.level);
        case "powerProfile":
            return root.exactKeys(data, ["active", "available"], [])
                && root.unpadded(data.active) && root.uniqueStrings(data.available)
                && data.available.indexOf(data.active) >= 0;
        case "media":
            return root.exactKeys(data, ["playerId", "title", "artist", "playing"], [])
                && root.unpadded(data.playerId) && typeof data.title === "string"
                && typeof data.artist === "string" && typeof data.playing === "boolean";
        case "nightLight":
            return root.exactKeys(data, ["enabled"], []) && typeof data.enabled === "boolean";
        case "niri":
            return root.exactKeys(data, ["outputIds", "workspaceIds", "windowIds"], [])
                && root.uniqueStrings(data.outputIds)
                && root.uniquePositiveIntegers(data.workspaceIds)
                && root.uniquePositiveIntegers(data.windowIds);
        case "resources":
            return root.exactKeys(data, ["cpuUsage", "memoryUsage", "loadOne"], [])
                && root.normalized(data.cpuUsage) && root.normalized(data.memoryUsage)
                && root.finite(data.loadOne) && data.loadOne >= 0;
        default: return false;
        }
    }

    function installCapability(record) {
        const normalized = root.normalizedCapability(record);
        if (!normalized)
            return false;
        const next = Object.assign({}, root.capabilities);
        next[normalized.id] = normalized;
        root.capabilities = Object.freeze(next);
        return true;
    }

    function capability(id) {
        if (Object.prototype.hasOwnProperty.call(root.capabilities, id))
            return root.capabilities[id];
        return Object.freeze({
            "id": id, "status": "unsupported", "available": false,
            "value": null, "diagnostic": "Capability has not reported"
        });
    }

    function applySnapshot(snapshot) {
        if (!root.exactKeys(snapshot, ["capabilities"], ["focusedOutputId"])
                || !Array.isArray(snapshot.capabilities)
                || snapshot.capabilities.length !== root.capabilityIds.length
                || (snapshot.focusedOutputId !== undefined
                    && !root.unpadded(snapshot.focusedOutputId)))
            return false;
        const next = {};
        for (const record of snapshot.capabilities) {
            const normalized = root.normalizedCapability(record);
            if (!normalized || Object.prototype.hasOwnProperty.call(next, normalized.id))
                return false;
            next[normalized.id] = normalized;
        }
        if (!root.capabilityIds.every(function(id) {
                return Object.prototype.hasOwnProperty.call(next, id);
            })) return false;
        root.capabilities = Object.freeze(next);
        root.focusedOutputId = typeof snapshot.focusedOutputId === "string"
                             ? snapshot.focusedOutputId : "";
        return true;
    }

    function applyPayload(payload) {
        if (!root.exactKeys(payload, ["type", "data"], [])
                || typeof payload.type !== "string")
            return false;
        switch (payload.type) {
        case "fullSnapshot": return root.applySnapshot(payload.data);
        case "capabilityUpdate": return root.installCapability(payload.data);
        case "niri":
            if (!root.exactKeys(payload.data, [], ["focusedOutputId"])
                    || (payload.data.focusedOutputId !== undefined
                        && payload.data.focusedOutputId !== null
                        && !root.unpadded(payload.data.focusedOutputId))) return false;
            root.focusedOutputId = typeof payload.data.focusedOutputId === "string"
                                 ? payload.data.focusedOutputId : "";
            return true;
        case "notification":
            if (!root.exactKeys(payload.data, ["notificationId", "change"], [])
                    || !Number.isSafeInteger(payload.data.notificationId)
                    || payload.data.notificationId <= 0
                    || ["added", "updated", "archived", "actionExpired"]
                        .indexOf(payload.data.change) < 0) return false;
            root.notifications = Object.freeze(root.notifications.concat([
                Object.freeze(Object.assign({}, payload.data))
            ]).slice(-500));
            return true;
        case "provider":
            if (!root.exactKeys(payload.data, ["providerId", "online"], [])
                    || !root.unpadded(payload.data.providerId)
                    || typeof payload.data.online !== "boolean") return false;
            const providers = Object.assign({}, root.providerStates);
            providers[payload.data.providerId] = Boolean(payload.data.online);
            root.providerStates = Object.freeze(providers);
            return true;
        case "theme":
            if (!root.exactKeys(payload.data, ["themeId", "applied"], [])
                    || !root.unpadded(payload.data.themeId)
                    || typeof payload.data.applied !== "boolean") return false;
            root.lastThemeEvent = Object.freeze(Object.assign({}, payload.data)); return true;
        case "lifecycle":
            if (!root.exactKeys(payload.data, ["state"], [])
                    || ["ready", "stopping", "reconciled"].indexOf(payload.data.state) < 0) return false;
            root.lifecycleState = payload.data.state;
            return true;
        default: return false;
        }
    }

    function acceptLine(line) {
        let envelope;
        try { envelope = JSON.parse(String(line)); }
        catch (error) { return root.fail("Malformed event JSON"); }
        if (!root.exactKeys(envelope,
                            ["schemaVersion", "generation", "eventId", "emittedAt", "cause", "payload"], [])
                || envelope.schemaVersion !== 2
                || typeof envelope.generation !== "number"
                || !Number.isSafeInteger(envelope.generation) || envelope.generation <= 0
                || !root.canonicalUuid(envelope.eventId)
                || typeof envelope.emittedAt !== "string"
                || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z$/.test(envelope.emittedAt)
                || Number.isNaN(Date.parse(envelope.emittedAt))
                || !root.exactKeys(envelope.cause, ["kind"], ["requestId"])
                || ["external", "request", "replay", "lifecycle"].indexOf(envelope.cause.kind) < 0
                || (envelope.cause.kind === "request" && !root.canonicalUuid(envelope.cause.requestId))
                || (envelope.cause.kind !== "request" && envelope.cause.requestId !== undefined))
            return root.fail("Invalid event envelope");
        if (!root.snapshotReceived && envelope.payload.type !== "fullSnapshot")
            return root.fail("First event was not a full snapshot");
        if (!root.snapshotReceived && envelope.generation < root.generation)
            return root.fail("Replay generation regressed");
        if (root.snapshotReceived && envelope.generation <= root.generation)
            return root.fail("Event generation did not increase");
        if (!root.applyPayload(envelope.payload))
            return root.fail("Invalid or unknown event payload");
        root.generation = envelope.generation;
        root.snapshotReceived = true;
        root.connectionState = "ready";
        root.diagnostic = "";
        root.eventAccepted(Object.freeze(envelope));
        return true;
    }
}
