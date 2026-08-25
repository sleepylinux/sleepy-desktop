// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0

QtObject {
    id: root
    property string pendingRequestId: ""
    property string pendingOperation: ""
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
        root.pendingOperation = "";
        return false;
    }
    function request(type, data, requestId) {
        if (root.pendingRequestId.length > 0 || root.operationTypes.indexOf(type) < 0) return null;
        const id = requestId || root.uuid();
        if (!root.canonicalUuid(id)) return null;
        root.pendingRequestId = id;
        root.pendingOperation = type;
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
        if (response.status === "confirmed" && !root.validResult(root.pendingOperation, response.data))
            return root.failResponse("Invalid " + root.pendingOperation + " response data");
        root.status = response.status === "confirmed" ? "ready" : response.status;
        root.errorString = typeof response.error === "string" ? response.error : "";
        root.result = response.data === undefined ? null : response.data;
        root.pendingRequestId = "";
        root.pendingOperation = "";
        if (root.status === "ready") root.responseAccepted(root.result);
        return root.status === "ready";
    }
    function exactKeys(value, expected) {
        if (!value || typeof value !== "object" || Array.isArray(value)) return false;
        const actual = Object.keys(value).sort();
        const wanted = expected.slice().sort();
        return actual.length === wanted.length
            && actual.every(function(key, index) { return key === wanted[index]; });
    }
    function nonEmpty(value) {
        return typeof value === "string" && value.length > 0 && value.trim() === value;
    }
    function timestamp(value) {
        if (typeof value !== "string") return false;
        const match = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?Z$/.exec(value);
        const milliseconds = Date.parse(value);
        if (!match || !Number.isFinite(milliseconds)) return false;
        const parsed = new Date(milliseconds);
        return parsed.getUTCFullYear() === Number(match[1])
            && parsed.getUTCMonth() + 1 === Number(match[2])
            && parsed.getUTCDate() === Number(match[3])
            && parsed.getUTCHours() === Number(match[4])
            && parsed.getUTCMinutes() === Number(match[5])
            && parsed.getUTCSeconds() === Number(match[6]);
    }
    function validLocation(value) {
        return root.exactKeys(value, ["displayName", "latitude", "longitude"])
            && root.nonEmpty(value.displayName) && Number.isFinite(value.latitude)
            && value.latitude >= -90 && value.latitude <= 90
            && Number.isFinite(value.longitude) && value.longitude >= -180
            && value.longitude <= 180;
    }
    function validLauncherEntry(value) {
        if (!value || typeof value !== "object" || Array.isArray(value)) return false;
        const keys = Object.keys(value);
        if (keys.some(function(key) { return ["desktopId", "name", "icon", "actions"].indexOf(key) < 0; })
                || !["desktopId", "name", "icon", "actions"].every(function(key) { return keys.indexOf(key) >= 0; })
                || !root.nonEmpty(value.desktopId) || !value.desktopId.endsWith(".desktop")
                || !root.nonEmpty(value.name) || !(value.icon === null || typeof value.icon === "string")
                || !Array.isArray(value.actions)) return false;
        return value.actions.every(function(action) {
            return root.exactKeys(action, ["id", "name"])
                && root.nonEmpty(action.id) && root.nonEmpty(action.name);
        });
    }
    function validCalendar(value) {
        if (!root.exactKeys(value, ["schemaVersion", "providerId", "windowStart", "windowEnd", "events", "sourceErrors"])
                || value.schemaVersion !== 2 || !root.nonEmpty(value.providerId)
                || !root.timestamp(value.windowStart) || !root.timestamp(value.windowEnd)
                || Date.parse(value.windowStart) >= Date.parse(value.windowEnd)
                || !Array.isArray(value.events) || !Array.isArray(value.sourceErrors)) return false;
        return value.events.every(function(event) {
            if (!event || typeof event !== "object" || Array.isArray(event)) return false;
            const keys = Object.keys(event);
            return keys.every(function(key) { return ["id", "summary", "startsAt", "endsAt", "allDay", "sourceId", "location"].indexOf(key) >= 0; })
                && ["id", "summary", "startsAt", "endsAt", "allDay", "sourceId"].every(function(key) { return keys.indexOf(key) >= 0; })
                && root.nonEmpty(event.id) && root.nonEmpty(event.summary)
                && root.timestamp(event.startsAt) && root.timestamp(event.endsAt)
                && Date.parse(event.startsAt) < Date.parse(event.endsAt)
                && typeof event.allDay === "boolean" && root.nonEmpty(event.sourceId)
                && (!Object.prototype.hasOwnProperty.call(event, "location") || event.location === null || typeof event.location === "string");
        }) && value.sourceErrors.every(function(error) {
            return root.exactKeys(error, ["sourceId", "message"])
                && root.nonEmpty(error.sourceId) && root.nonEmpty(error.message);
        });
    }
    function validWeather(value) {
        if (!value || typeof value !== "object" || Array.isArray(value)) return false;
        const keys = Object.keys(value);
        if (keys.some(function(key) { return ["schemaVersion", "providerId", "location", "status", "cache", "attribution", "forecast", "diagnostic"].indexOf(key) < 0; })
                || !["schemaVersion", "providerId", "location", "status", "cache", "attribution", "forecast"].every(function(key) { return keys.indexOf(key) >= 0; })
                || value.schemaVersion !== 2 || !root.nonEmpty(value.providerId)
                || !root.validLocation(value.location)
                || ["online", "offline", "error"].indexOf(value.status) < 0
                || ["fresh", "stale", "missing"].indexOf(value.cache) < 0
                || !root.nonEmpty(value.attribution) || !Array.isArray(value.forecast)) return false;
        const hasDiagnostic = Object.prototype.hasOwnProperty.call(value, "diagnostic");
        if ((value.status === "online" && hasDiagnostic)
                || (value.status !== "online" && (!hasDiagnostic
                    || !root.exactKeys(value.diagnostic, ["message"])
                    || !root.nonEmpty(value.diagnostic.message)))) return false;
        return value.forecast.every(function(point) {
            return root.exactKeys(point, ["at", "temperatureC", "symbol"])
                && root.timestamp(point.at) && Number.isFinite(point.temperatureC)
                && root.nonEmpty(point.symbol);
        });
    }
    function validResult(operation, data) {
        if (operation === "launcherSearch")
            return Array.isArray(data) && data.every(root.validLauncherEntry);
        if (operation === "launch")
            return root.exactKeys(data, ["desktopId"]) && root.nonEmpty(data.desktopId)
                && data.desktopId.endsWith(".desktop");
        if (operation === "overview")
            return root.exactKeys(data, ["confirmed"]) && data.confirmed === true;
        if (operation === "calendar") return root.validCalendar(data);
        if (operation === "weather") return root.validWeather(data);
        if (operation === "geocodeSubmit")
            return Array.isArray(data) && data.every(root.validLocation);
        return false;
    }
}
