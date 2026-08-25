// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0

QtObject {
    id: root
    property string pendingRequestId: ""
    property string status: "idle"
    property string errorString: ""
    property var result: null
    signal responseAccepted(var data)

    readonly property var operationTypes: Object.freeze([
        "launcherSearch", "launch", "overview", "calendar", "weather", "geocodeSubmit"
    ])

    function uuid() {
        let pattern = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx";
        return pattern.replace(/[xy]/g, function(character) {
            const value = Math.floor(Math.random() * 16);
            return (character === "x" ? value : (value & 3) | 8).toString(16);
        });
    }
    function canonicalUuid(value) {
        return typeof value === "string"
            && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(value);
    }
    function failResponse(message) {
        root.status = "error";
        root.errorString = message;
        root.pendingRequestId = "";
        return false;
    }
    function request(type, data, requestId) {
        if (root.pendingRequestId.length > 0 || root.operationTypes.indexOf(type) < 0) return null;
        const id = requestId || root.uuid();
        if (!root.canonicalUuid(id)) return null;
        root.pendingRequestId = id;
        root.status = "loading";
        root.errorString = "";
        return Object.freeze({
            "schemaVersion": 2, "requestId": id,
            "operation": Object.freeze({"type": type, "data": Object.freeze(data || {})})
        });
    }
    function launcherSearch(query, requestId) {
        return root.request("launcherSearch", {"query": String(query)}, requestId);
    }
    function launch(desktopId, actionId, files, urls, requestId) {
        if (typeof desktopId !== "string" || desktopId.trim() !== desktopId
                || !desktopId.endsWith(".desktop") || desktopId.indexOf("/") >= 0
                || desktopId.indexOf("\\") >= 0 || desktopId.indexOf("..") >= 0
                || (actionId !== null && actionId !== undefined
                    && (typeof actionId !== "string" || actionId.trim() !== actionId
                        || actionId.length === 0))) return null;
        const resources = (Array.isArray(files) ? files : [])
            .concat(Array.isArray(urls) ? urls : []);
        if (!resources.every(function(value) {
                return typeof value === "string" && value.length > 0
                    && value.indexOf("\u0000") < 0;
            })) return null;
        return root.request("launch", {"request": {
            "schemaVersion": 2,
            "desktopId": desktopId.trim(),
            "actionId": actionId || null,
            "resources": resources
        }}, requestId);
    }
    function overview(command, data, requestId) {
        const allowed = ["focusWindow", "closeWindow", "focusWorkspace"];
        if (allowed.indexOf(command) < 0) return null;
        const field = command === "focusWorkspace" ? "workspaceId" : "windowId";
        if (!data || Object.keys(data).length !== 1
                || !Number.isSafeInteger(data[field]) || data[field] <= 0) return null;
        return root.request("overview", {"command": {"type": command, "data": data}}, requestId);
    }
    function calendar(windowStart, windowEnd, requestId) {
        return root.request("calendar", {"windowStart": windowStart, "windowEnd": windowEnd}, requestId);
    }
    function weather(location, requestId) {
        return root.request("weather", {"location": location}, requestId);
    }
    function geocodeSubmit(query, requestId) {
        if (typeof query !== "string" || query.trim().length === 0) return null;
        return root.request("geocodeSubmit", {"query": query.trim()}, requestId);
    }
    function acceptResponse(line) {
        let response;
        try { response = JSON.parse(String(line)); } catch (error) {
            return root.failResponse("Malformed daily response");
        }
        const keys = Object.keys(response);
        if (keys.some(function(key) { return ["schemaVersion", "requestId", "status", "data", "error"].indexOf(key) < 0; })
                || keys.indexOf("schemaVersion") < 0 || keys.indexOf("requestId") < 0
                || keys.indexOf("status") < 0
                || response.schemaVersion !== 2 || response.requestId !== root.pendingRequestId
                || ["confirmed", "busy", "error"].indexOf(response.status) < 0) {
            return root.failResponse("Mismatched daily response");
        }
        const ownsData = Object.prototype.hasOwnProperty.call(response, "data");
        const ownsError = Object.prototype.hasOwnProperty.call(response, "error");
        if ((response.status === "confirmed" && (!ownsData || ownsError))
                || (response.status !== "confirmed" && (ownsData || !ownsError
                    || typeof response.error !== "string"
                    || response.error.trim().length === 0)))
            return root.failResponse("Invalid daily response status fields");
        root.status = response.status === "confirmed" ? "ready" : response.status;
        root.errorString = typeof response.error === "string" ? response.error : "";
        root.result = response.data === undefined ? null : response.data;
        root.pendingRequestId = "";
        if (root.status === "ready") root.responseAccepted(root.result);
        return root.status === "ready";
    }
}
