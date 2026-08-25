// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0

QtObject {
    id: root
    property string pendingRequestId: ""
    property double expectedGeneration: 0
    property double responseGeneration: 0
    property string status: "idle"
    property string errorString: ""
    signal confirmed(string requestId, double generation)

    function uuid() { return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, function(c) { const v = Math.floor(Math.random() * 16); return (c === "x" ? v : (v & 3) | 8).toString(16); }); }
    function canonicalUuid(value) { return typeof value === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(value); }
    function exact(value, keys) { if (!value || typeof value !== "object" || Array.isArray(value)) return false; const actual = Object.keys(value).sort(); const wanted = keys.slice().sort(); return actual.length === wanted.length && actual.every(function(k, i) { return k === wanted[i]; }); }
    function normalized(value) { return typeof value === "number" && Number.isFinite(value) && value >= 0 && value <= 1; }
    function validMutation(capability, value) {
        if (["network.enabled", "bluetooth.enabled", "audio.muted", "audio.microphoneMuted", "display.nightLightEnabled"].indexOf(capability) >= 0) return typeof value === "boolean";
        if (["audio.volume", "audio.microphoneLevel", "display.brightness"].indexOf(capability) >= 0) return root.normalized(value);
        if (capability === "audio.outputDevice") return typeof value === "string" && value.length > 0;
        if (capability === "power.profile") return ["power-saver", "balanced", "performance"].indexOf(value) >= 0;
        if (capability === "media.transport") return ["playPause", "next", "previous"].indexOf(value) >= 0;
        return false;
    }
    function mutation(capability, value, generation, requestId) {
        if (root.pendingRequestId || !root.validMutation(capability, value)
                || !Number.isSafeInteger(generation) || generation <= 0) return null;
        const id = requestId || root.uuid(); if (!root.canonicalUuid(id)) return null;
        root.pendingRequestId = id; root.expectedGeneration = generation; root.status = "loading"; root.errorString = "";
        return Object.freeze({"schemaVersion": 2, "requestId": id, "expectedGeneration": generation,
            "command": Object.freeze({"type": "setCapability", "data": Object.freeze({
                "mutation": Object.freeze({"capability": capability, "value": value})})})});
    }
    function acceptResponse(line) {
        let value; try { value = JSON.parse(String(line)); } catch (error) { return root.fail("Malformed control response"); }
        if (!value || value.schemaVersion !== 2 || value.requestId !== root.pendingRequestId
                || !Number.isSafeInteger(value.generation) || value.generation <= 0
                || ["confirmed", "rejected", "unknown"].indexOf(value.status) < 0)
            return root.fail("Invalid control result");
        if (value.status !== "confirmed") {
            if (!root.exact(value, ["schemaVersion", "requestId", "generation", "status", "error"])
                    || !root.exact(value.error, ["code", "message"])
                    || typeof value.error.code !== "string" || !value.error.code.length
                    || typeof value.error.message !== "string" || !value.error.message.length)
                return root.fail("Invalid control failure");
            return root.fail(value.error.message);
        }
        const event = value.confirmedEvent;
        if (!root.exact(value, ["schemaVersion", "requestId", "generation", "status", "confirmedEvent"])
                || value.generation <= root.expectedGeneration || !event
                || !root.exact(event, ["schemaVersion","generation","eventId","emittedAt","cause","payload"])
                || event.schemaVersion !== 2 || event.generation !== value.generation
                || !root.canonicalUuid(event.eventId) || typeof event.emittedAt !== "string" || !event.emittedAt.length
                || !root.exact(event.cause, ["kind", "requestId"])
                || event.cause.kind !== "request" || event.cause.requestId !== value.requestId
                || !root.exact(event.payload, ["type","data"])
                || event.payload.type !== "fullSnapshot" || !event.payload.data
                || !Array.isArray(event.payload.data.capabilities)) return root.fail("Invalid control confirmation");
        root.responseGeneration = value.generation; root.status = "awaitingEvent";
        root.confirmed(value.requestId, value.generation); return true;
    }
    function complete() { root.status = "confirmed"; root.pendingRequestId = ""; }
    function fail(message) { root.status = "error"; root.errorString = message; root.pendingRequestId = ""; return false; }
}
