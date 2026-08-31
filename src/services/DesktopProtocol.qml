// SPDX-License-Identifier: GPL-3.0-only
// Modified for Sleepy on 2026-08-31: daemon-owned desktop runtime protocol.

import QtQuick 6.0

QtObject {
    id: root

    property string eventSocketPath: ""
    property string controlSocketPath: ""
    property int minimumRetryMs: 250
    property int maximumRetryMs: 10000
    property int maximumObservedRequests: 64
    property string connectionState: "offline"
    property string diagnostic: "Waiting for sleepy-sessiond"
    property int generation: 0
    property var snapshot: Object.freeze({})
    property var observedRequestIds: Object.freeze({})
    property var observedRequestOrder: Object.freeze([])
    property var lastCommandResult: null
    property bool snapshotReceived: false

    signal eventAccepted(var envelope)
    signal commandResultAccepted(var result)
    signal protocolError(string message)
    signal daemonGenerationChanged(int generation)

    readonly property var topics: Object.freeze([
        "system", "compositor", "notifications", "launcher", "calendar",
        "weather", "appearance", "resources", "utilities"
    ])

    function own(object, key) {
        return object && Object.prototype.hasOwnProperty.call(object, key);
    }

    function exact(value, required, optional) {
        if (!value || typeof value !== "object" || Array.isArray(value))
            return false;
        const allowed = required.concat(optional || []);
        const keys = Object.keys(value);
        return required.every(key => keys.indexOf(key) >= 0)
            && keys.every(key => allowed.indexOf(key) >= 0);
    }

    function canonicalUuid(value) {
        return typeof value === "string"
            && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(value);
    }

    function positiveInteger(value) {
        return Number.isSafeInteger(value) && value > 0;
    }

    function nonEmpty(value) {
        return typeof value === "string" && value.trim() === value && value.length > 0;
    }

    function validCause(cause) {
        if (!cause || typeof cause !== "object" || Array.isArray(cause))
            return false;
        if (cause.kind === "request")
            return root.exact(cause, ["kind", "requestId"], [])
                && root.canonicalUuid(cause.requestId);
        return root.exact(cause, ["kind"], [])
            && ["external", "replay", "lifecycle"].indexOf(cause.kind) >= 0;
    }

    function beginConnection() {
        root.connectionState = "connecting";
        root.diagnostic = "Waiting for full desktop snapshot";
        root.snapshotReceived = false;
    }

    function disconnected(message) {
        root.connectionState = "offline";
        root.diagnostic = message || "sleepy-sessiond desktop stream disconnected";
        root.snapshotReceived = false;
    }

    function fail(message) {
        root.connectionState = "error";
        root.diagnostic = message;
        root.protocolError(message);
        return false;
    }

    function boundedRetryDelay(attempt) {
        const floor = Math.max(1, root.minimumRetryMs);
        const ceiling = Math.max(floor, root.maximumRetryMs);
        const raw = floor * Math.pow(2, Math.max(0, attempt));
        return Math.min(ceiling, raw);
    }

    function rememberRequest(requestId, generation) {
        if (!root.canonicalUuid(requestId))
            return;
        const observed = Object.assign({}, root.observedRequestIds);
        let order = root.observedRequestOrder.slice();
        if (!root.own(observed, requestId))
            order.push(requestId);
        observed[requestId] = generation;
        const maximum = Math.max(1, root.maximumObservedRequests);
        while (order.length > maximum) {
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

    function domain(name) {
        return root.snapshot && root.own(root.snapshot, name) ? root.snapshot[name] : null;
    }

    function capability(id) {
        const system = root.domain("system") || {};
        let record = system[id] || null;
        if (!record && id === "powerProfile")
            record = system.power || null;
        if (!record && id === "niri") {
            const compositor = root.domain("compositor") || {};
            record = compositor.hyprland || null;
        }
        if (!record || typeof record !== "object")
            return Object.freeze({
                "id": id, "status": "unsupported", "available": false,
                "value": null, "diagnostic": "Capability has not reported"
            });
        if (record.status === "available")
            return Object.freeze({
                "id": id, "status": "available", "available": true,
                "value": Object.freeze({"type": id, "data": root.legacyCapabilityData(id, record.data)}),
                "diagnostic": ""
            });
        return Object.freeze({
            "id": id, "status": record.status || "unavailable",
            "available": false, "value": null,
            "diagnostic": record.diagnostic && record.diagnostic.message
                          ? record.diagnostic.message : (record.status || "unavailable")
        });
    }

    function legacyCapabilityData(id, data) {
        data = data || {};
        switch (id) {
        case "network": {
            const connections = Array.isArray(data.connections) ? data.connections : [];
            const active = connections.find(item => item.connected);
            return {
                "wifiEnabled": Boolean(data.wifiEnabled),
                "ethernetConnected": connections.some(item => item.kind === "ethernet" && item.connected),
                "connectivity": active ? "full" : "none",
                "activeConnectionId": active ? active.id : ""
            };
        }
        case "bluetooth":
            return {
                "powered": Boolean(data.powered),
                "connectedDeviceIds": Array.isArray(data.devices)
                    ? data.devices.filter(item => item.connected).map(item => item.id) : []
            };
        case "audio": {
            const nodes = Array.isArray(data.nodes) ? data.nodes : [];
            const output = nodes.find(item => item.kind === "output" && item.isDefault)
                         || nodes.find(item => item.kind === "output") || {};
            const input = nodes.find(item => item.kind === "input" && item.isDefault)
                        || nodes.find(item => item.kind === "input") || {};
            return {
                "outputLevel": Number.isFinite(output.volume) ? output.volume : 0,
                "outputMuted": Boolean(output.muted),
                "inputLevel": Number.isFinite(input.volume) ? input.volume : 0,
                "inputMuted": Boolean(input.muted),
                "defaultOutputId": output.id || ""
            };
        }
        case "battery":
            return {
                "percentage": Math.round((Number.isFinite(data.level) ? data.level : 0) * 100),
                "charging": Boolean(data.charging),
                "secondsRemaining": Number.isSafeInteger(data.secondsRemaining)
                                    ? data.secondsRemaining : 0
            };
        case "brightness":
            return {"level": Number.isFinite(data.level) ? data.level : 0};
        case "powerProfile":
            return {
                "active": data.activeProfile || "balanced",
                "available": Array.isArray(data.availableProfiles)
                             ? data.availableProfiles : ["balanced"]
            };
        case "media": {
            const player = Array.isArray(data.players) && data.players.length ? data.players[0] : {};
            return {
                "playerId": player.id || "none",
                "title": player.title || "",
                "artist": player.artist || "",
                "playing": Boolean(player.playing)
            };
        }
        case "nightLight":
            return {"enabled": Boolean(data.enabled)};
        case "niri": {
            const monitors = Array.isArray(data.monitors) ? data.monitors : [];
            const workspaces = Array.isArray(data.workspaces) ? data.workspaces : [];
            const windows = Array.isArray(data.windows) ? data.windows : [];
            return {
                "outputIds": monitors.map(item => item.id || item.name).filter(Boolean),
                "workspaceIds": workspaces.map(item => parseInt(item.id, 10)).filter(Number.isSafeInteger),
                "windowIds": windows.map((_item, index) => index + 1)
            };
        }
        case "resources": {
            const samples = Array.isArray(data.samples) ? data.samples : [];
            const sample = samples.length ? samples[0] : {};
            return {
                "cpuUsage": Number.isFinite(sample.cpuUsage) ? sample.cpuUsage : 0,
                "memoryUsage": Number.isFinite(sample.memoryUsage) ? sample.memoryUsage : 0,
                "loadOne": Number.isFinite(sample.loadOne) ? sample.loadOne : 0
            };
        }
        default:
            return data;
        }
    }

    function applyDomainUpdate(update) {
        if (!root.exact(update, ["topic", "update"], [])
                || root.topics.indexOf(update.topic) < 0)
            return false;
        const next = Object.assign({}, root.snapshot);
        if (root.exact(update.update, ["domain", "data"], [])) {
            const topic = Object.assign({}, next[update.topic] || {});
            topic[update.update.domain] = update.update.data;
            next[update.topic] = Object.freeze(topic);
        } else {
            next[update.topic] = update.update;
        }
        root.snapshot = Object.freeze(next);
        return true;
    }

    function validCommandResult(result) {
        if (!result || result.schemaVersion !== 3 || !root.canonicalUuid(result.requestId)
                || !root.positiveInteger(result.generation)
                || ["succeeded", "failed"].indexOf(result.status) < 0)
            return false;
        if (result.status === "succeeded")
            return root.exact(result, ["schemaVersion", "requestId", "generation", "status"], []);
        return root.exact(result, ["schemaVersion", "requestId", "generation", "status", "diagnostic"], [])
            && root.exact(result.diagnostic, ["message"], [])
            && root.nonEmpty(result.diagnostic.message);
    }

    function applyPayload(payload) {
        if (!root.exact(payload, ["type", "data"], [])
                || ["fullSnapshot", "domainUpdate", "commandResult"].indexOf(payload.type) < 0)
            return false;
        switch (payload.type) {
        case "fullSnapshot":
            if (!payload.data || typeof payload.data !== "object" || Array.isArray(payload.data))
                return false;
            root.snapshot = Object.freeze(Object.assign({}, payload.data));
            return true;
        case "domainUpdate":
            return root.applyDomainUpdate(payload.data);
        case "commandResult":
            if (!root.validCommandResult(payload.data))
                return false;
            root.lastCommandResult = Object.freeze(Object.assign({}, payload.data));
            root.rememberRequest(payload.data.requestId, payload.data.generation);
            root.commandResultAccepted(root.lastCommandResult);
            return true;
        default:
            return false;
        }
    }

    function acceptEnvelope(envelope) {
        if (!root.exact(envelope,
                        ["schemaVersion", "generation", "eventId", "emittedAt", "cause", "payload"], [])
                || envelope.schemaVersion !== 3
                || !root.positiveInteger(envelope.generation)
                || !root.canonicalUuid(envelope.eventId)
                || !root.nonEmpty(envelope.emittedAt)
                || Number.isNaN(Date.parse(envelope.emittedAt))
                || !root.validCause(envelope.cause))
            return root.fail("Invalid desktop event envelope");
        if (!root.snapshotReceived && envelope.payload.type !== "fullSnapshot")
            return root.fail("First desktop event was not a full snapshot");
        if (root.snapshotReceived && envelope.generation <= root.generation)
            return root.fail("Desktop event generation did not increase");
        if (!root.snapshotReceived && envelope.generation < root.generation)
            return root.fail("Replay generation regressed");
        if (!root.applyPayload(envelope.payload))
            return root.fail("Invalid desktop event payload");

        if (envelope.generation !== root.generation) {
            root.generation = envelope.generation;
            root.clearObservedRequests();
            root.daemonGenerationChanged(root.generation);
        }
        if (envelope.cause.kind === "request")
            root.rememberRequest(envelope.cause.requestId, envelope.generation);
        root.snapshotReceived = true;
        root.connectionState = "ready";
        root.diagnostic = "";
        root.eventAccepted(Object.freeze(envelope));
        return true;
    }

    function acceptLine(line) {
        let envelope;
        try {
            envelope = JSON.parse(String(line));
        } catch (error) {
            return root.fail("Malformed desktop event JSON");
        }
        return root.acceptEnvelope(envelope);
    }

    function acceptCommandResult(result) {
        if (!root.validCommandResult(result))
            return false;
        root.lastCommandResult = Object.freeze(Object.assign({}, result));
        root.rememberRequest(result.requestId, result.generation);
        root.commandResultAccepted(root.lastCommandResult);
        return true;
    }
}
