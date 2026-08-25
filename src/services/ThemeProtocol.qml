// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0

QtObject {
    id: root
    property string pendingRequestId: ""
    property var previewTheme: null
    property var confirmedTheme: null
    property string status: "loading"
    property string errorString: ""
    property double confirmedGeneration: 0
    property bool mutationsEnabled: false
    signal candidateReceived(var theme)
    signal rollbackRequested(var theme)
    signal resultReceived(string status)

    function uuid() {
        let pattern = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx";
        return pattern.replace(/[xy]/g, function(character) {
            const value = Math.floor(Math.random() * 16);
            return (character === "x" ? value : (value & 3) | 8).toString(16);
        });
    }
    function request(operation, requestId) {
        if (root.pendingRequestId.length > 0) return null;
        const id = requestId || root.uuid();
        root.pendingRequestId = id; root.status = "loading";
        return Object.freeze({"schemaVersion": 2, "requestId": id, "operation": operation});
    }
    function get(requestId) { return root.request({"type": "get"}, requestId); }
    function apply(themeId, expectedGeneration, requestId) {
        if (!root.mutationsEnabled || typeof themeId !== "string" || themeId.length === 0
                || !Number.isSafeInteger(expectedGeneration) || expectedGeneration <= 0) return null;
        return root.request({"type": "apply", "data": {
            "themeId": themeId, "expectedGeneration": expectedGeneration
        }}, requestId);
    }
    function exactKeys(value, expected) {
        if (!value || typeof value !== "object" || Array.isArray(value)) return false;
        const actual = Object.keys(value).sort();
        const wanted = expected.slice().sort();
        return actual.length === wanted.length
            && actual.every(function(key, index) { return key === wanted[index]; });
    }
    function validTheme(theme) {
        if (!root.exactKeys(theme, ["schemaVersion", "id", "name", "origin", "appearance",
                                          "effects", "reducedMotion", "opaqueFallback", "colors"])
                || theme.schemaVersion !== 1 || typeof theme.id !== "string" || !theme.id.length
                || typeof theme.name !== "string" || !theme.name.length
                || ["builtin", "user"].indexOf(theme.origin) < 0
                || ["dark", "light", "system"].indexOf(theme.appearance) < 0
                || ["full", "reduced", "none"].indexOf(theme.effects) < 0
                || typeof theme.reducedMotion !== "boolean"
                || typeof theme.opaqueFallback !== "boolean"
                || !root.exactKeys(theme.colors, ["background", "surface", "textPrimary",
                                                    "textSecondary", "accent", "control"]))
            return false;
        return Object.keys(theme.colors).every(function(key) {
            return typeof theme.colors[key] === "string"
                && /^#[0-9a-fA-F]{6}$/.test(theme.colors[key]);
        });
    }
    function acceptLine(line) {
        let message;
        try { message = JSON.parse(String(line)); } catch (error) {
            root.status = "error"; root.errorString = "Malformed theme message"; return false;
        }
        if (!root.exactKeys(message, ["type", "data"])
                || ["candidate", "result"].indexOf(message.type) < 0
                || !message.data || message.data.schemaVersion !== 2
                || message.data.requestId !== root.pendingRequestId) {
            root.status = "error"; root.errorString = "Invalid theme message"; return false;
        }
        if (message.type === "candidate") {
            if (!root.exactKeys(message.data, ["schemaVersion", "requestId", "theme"]))
                return false;
            if (!root.validTheme(message.data.theme)) {
                root.status = "error"; root.errorString = "Invalid theme candidate"; return false;
            }
            root.previewTheme = Object.freeze(message.data.theme);
            root.candidateReceived(root.previewTheme);
            return true;
        }
        const resultKeys = Object.keys(message.data);
        if (!["schemaVersion", "requestId", "status"].every(function(key) {
                return resultKeys.indexOf(key) >= 0;
            }) || resultKeys.some(function(key) {
                return ["schemaVersion", "requestId", "status", "generation", "theme", "error"].indexOf(key) < 0;
            }) || ["confirmed", "reconciled", "unavailable", "error", "busy", "timeout", "cancelled"]
                .indexOf(message.data.status) < 0) return false;
        root.status = message.data.status;
        root.errorString = message.data.error || "";
        if ((root.status === "confirmed" || root.status === "reconciled") && message.data.theme) {
            if (!root.validTheme(message.data.theme)) {
                root.status = "error"; root.errorString = "Invalid confirmed theme"; return false;
            }
            root.confirmedTheme = Object.freeze(message.data.theme);
            root.previewTheme = null;
            if (Number.isSafeInteger(message.data.generation))
                root.confirmedGeneration = message.data.generation;
            root.mutationsEnabled = true;
        } else if (root.previewTheme) {
            root.previewTheme = null;
            if (root.confirmedTheme) root.rollbackRequested(root.confirmedTheme);
        }
        root.resultReceived(root.status);
        root.pendingRequestId = "";
        return true;
    }
    function acknowledgement(accepted) {
        if (!root.previewTheme || root.pendingRequestId.length === 0) return null;
        return Object.freeze({"schemaVersion": 2, "requestId": root.pendingRequestId,
                              "accepted": Boolean(accepted)});
    }
}
