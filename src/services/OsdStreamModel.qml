// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0

QtObject {
    id: root
    property double sequence: 0
    property var visibleByOutput: Object.freeze({})
    property var overflowByOutput: Object.freeze({})
    property string state: "loading"
    property string diagnostic: ""
    signal publicationAccepted(double sequence)

    function beginConnection() {
        root.sequence = 0;
        root.visibleByOutput = Object.freeze({});
        root.overflowByOutput = Object.freeze({});
        root.state = "loading";
        root.diagnostic = "Waiting for OSD replay";
    }
    function disconnected(message) {
        root.sequence = 0;
        root.visibleByOutput = Object.freeze({});
        root.overflowByOutput = Object.freeze({});
        root.state = "offline";
        root.diagnostic = message || "OSD service unavailable";
    }

    function exactKeys(value, required, optional) {
        if (!value || typeof value !== "object" || Array.isArray(value)) return false;
        const allowed = required.concat(optional || []);
        const keys = Object.keys(value);
        return required.every(function(key) { return keys.indexOf(key) >= 0; })
            && keys.every(function(key) { return allowed.indexOf(key) >= 0; });
    }
    function unpadded(value) {
        return typeof value === "string" && value.length > 0 && value.trim() === value;
    }
    function validItem(item) {
        if (!root.exactKeys(item, ["schemaVersion", "outputId", "kind", "label"],
                            ["level", "muted"])
                || item.schemaVersion !== 2 || !root.unpadded(item.outputId)
                || !root.unpadded(item.label)
                || ["volume", "microphone", "brightness", "media", "powerProfile"]
                    .indexOf(item.kind) < 0
                || (item.level !== undefined && (typeof item.level !== "number"
                    || !Number.isFinite(item.level) || item.level < 0 || item.level > 1))
                || (item.muted !== undefined && typeof item.muted !== "boolean")) return false;
        if (["volume", "microphone", "brightness"].indexOf(item.kind) >= 0
                && item.level === undefined) return false;
        return !(item.kind === "brightness" && item.muted !== undefined);
    }

    function acceptLine(line) {
        let publication;
        try { publication = JSON.parse(String(line)); } catch (error) {
            root.state = "error"; root.diagnostic = "Malformed OSD publication"; return false;
        }
        const keys = Object.keys(publication);
        if (keys.length !== 3 || keys.indexOf("sequence") < 0
                || keys.indexOf("visible") < 0 || keys.indexOf("overflowByOutput") < 0
                || !Number.isSafeInteger(publication.sequence) || publication.sequence <= root.sequence
                || !Array.isArray(publication.visible)
                || !publication.overflowByOutput || Array.isArray(publication.overflowByOutput)) {
            root.state = "error"; root.diagnostic = "Invalid OSD publication"; return false;
        }
        const visible = {};
        for (const item of publication.visible) {
            if (!root.validItem(item)
                    || Object.prototype.hasOwnProperty.call(visible, item.outputId)) {
                root.state = "error"; root.diagnostic = "Invalid per-output OSD item"; return false;
            }
            visible[item.outputId] = Object.freeze(Object.assign({}, item));
        }
        const overflowKeys = Object.keys(publication.overflowByOutput);
        if (!overflowKeys.every(function(outputId) {
                const value = publication.overflowByOutput[outputId];
                return root.unpadded(outputId) && Number.isSafeInteger(value) && value >= 0;
            })) {
            root.state = "error"; root.diagnostic = "Invalid OSD overflow diagnostics"; return false;
        }
        root.sequence = publication.sequence;
        root.visibleByOutput = Object.freeze(visible);
        root.overflowByOutput = Object.freeze(Object.assign({}, publication.overflowByOutput));
        root.state = "ready"; root.diagnostic = "";
        root.publicationAccepted(root.sequence);
        return true;
    }
    function visibleFor(outputId) {
        return Object.prototype.hasOwnProperty.call(root.visibleByOutput, outputId)
             ? root.visibleByOutput[outputId] : null;
    }
    function overflowFor(outputId) {
        return Object.prototype.hasOwnProperty.call(root.overflowByOutput, outputId)
             ? root.overflowByOutput[outputId] : 0;
    }
}
