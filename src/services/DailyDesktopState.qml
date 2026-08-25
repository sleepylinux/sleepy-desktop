// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0

QtObject {
    id: root
    required property var events
    required property var daily
    property var themeClient: null
    readonly property NotificationCenterModel notifications: NotificationCenterModel {}
    property var launcherItems: Object.freeze([])
    property var overviewItems: Object.freeze([])
    property var calendarItems: Object.freeze([])
    property var weather: null
    property var geocodeItems: Object.freeze([])
    property string activeRequestKind: ""

    function request(kind, request) {
        if (!request) return false;
        root.activeRequestKind = kind;
        return root.daily.sendRequest(request);
    }
    function searchLauncher(query) { return root.request("launcher", root.daily.launcherSearch(query)); }
    function submitGeocode(query) { return root.request("geocode", root.daily.geocodeSubmit(query)); }
    function loadCalendar(start, end) { return root.request("calendar", root.daily.calendar(start, end)); }
    function loadWeather(location) { return root.request("weather", root.daily.weather(location)); }
    function runOverview(command, data) {
        return root.request("overview", root.daily.overview(command, data));
    }
    function launch(desktopId, actionId) {
        return root.request("launch", root.daily.launch(desktopId, actionId, [], []));
    }
    function applyTheme(themeId) {
        if (!root.themeClient || !root.themeClient.mutationsEnabled
                || !Number.isSafeInteger(root.events.generation)
                || root.events.generation <= 0) return false;
        const request = root.themeClient.apply(themeId, root.events.generation);
        return request ? root.themeClient.send(request) : false;
    }
    function activateItem(surfaceId, item) {
        if (!item || typeof item !== "object") return false;
        if (surfaceId === "launcher" && typeof item.desktopId === "string")
            return root.launch(item.desktopId, item.actionId || null);
        if (surfaceId === "overview" && item.kind === "workspace"
                && Number.isSafeInteger(Number(item.id)) && Number(item.id) > 0)
            return root.runOverview("focusWorkspace", {"workspaceId": Number(item.id)});
        if (surfaceId === "overview" && item.kind === "window"
                && Number.isSafeInteger(Number(item.id)) && Number(item.id) > 0)
            return root.runOverview("focusWindow", {"windowId": Number(item.id)});
        if (surfaceId === "widgets" && typeof item.displayName === "string"
                && Number.isFinite(item.latitude) && Number.isFinite(item.longitude))
            return root.loadWeather({"displayName": item.displayName,
                "latitude": item.latitude, "longitude": item.longitude});
        if (surfaceId === "personalization" && typeof item.id === "string")
            return root.applyTheme(item.id);
        return false;
    }
    function closeOverviewItem(item) {
        if (!item || item.kind !== "window" || !Number.isSafeInteger(Number(item.id))
                || Number(item.id) <= 0) return false;
        return root.runOverview("closeWindow", {"windowId": Number(item.id)});
    }
    function stateFor(surfaceId) {
        if (["notifications", "overview", "widgets"].indexOf(surfaceId) >= 0
                && root.events.connectionState !== "ready") return "offline";
        if (surfaceId === "overview") {
            const status = root.events.capability("niri").status;
            if (status !== "available") return status;
        }
        if (surfaceId === "notifications")
            return root.notifications.items.length ? "ready" : "empty";
        if (root.daily.status === "loading" && root.activeRequestKind === surfaceId) return "loading";
        if (["offline", "error", "busy"].indexOf(root.daily.status) >= 0
                && root.activeRequestKind === surfaceId) return root.daily.status;
        if (surfaceId === "widgets" && root.weather) {
            if (root.weather.cache === "stale") return "stale";
            if (root.weather.status === "offline") return "offline";
            if (root.weather.status === "error") return "error";
        }
        const data = root.itemsFor(surfaceId);
        return data && data.length ? "ready" : "empty";
    }
    function itemsFor(surfaceId) {
        if (surfaceId === "notifications") return root.notifications.items;
        if (surfaceId === "launcher") return root.launcherItems;
        if (surfaceId === "overview") {
            const niri = root.events.capability("niri");
            if (!niri.available || !niri.value) return [];
            const value = niri.value.data !== undefined ? niri.value.data : niri.value;
            const workspaces = (value.workspaceIds || []).map(function(id) {
                return Object.freeze({"id": id, "name": "Workspace " + id, "kind": "workspace"});
            });
            const windows = (value.windowIds || []).map(function(id) {
                return Object.freeze({"id": id, "name": "Window " + id, "kind": "window"});
            });
            return Object.freeze(workspaces.concat(windows));
        }
        if (surfaceId === "widgets") {
            const weatherRows = root.weather ? [Object.freeze({"id": "weather",
                "name": root.weather.attribution || "Weather"})] : [];
            return Object.freeze(root.systemCards().concat(weatherRows,
                root.geocodeItems, root.calendarItems));
        }
        if (surfaceId === "personalization" && root.themeClient
                && root.themeClient.confirmedTheme)
            return Object.freeze([root.themeClient.confirmedTheme]);
        return [];
    }
    function systemCards() {
        return ["resources", "network", "battery", "media", "bluetooth", "audio"].map(function(id) {
            return root.events.capability(id);
        });
    }
    readonly property Connections eventConnections: Connections {
        target: root.events
        function onEventAccepted(envelope) {
            if (envelope.payload.type === "notification")
                root.notifications.acceptEvent(envelope.payload.data);
        }
    }
    readonly property Connections dailyConnections: Connections {
        target: root.daily
        function onResponseAccepted(data) {
            switch (root.activeRequestKind) {
            case "launcher": root.launcherItems = Object.freeze(Array.isArray(data) ? data : []); break;
            case "overview": root.overviewItems = Object.freeze(Array.isArray(data) ? data : []); break;
            case "calendar": root.calendarItems = Object.freeze(data && Array.isArray(data.events) ? data.events : Array.isArray(data) ? data : []); break;
            case "weather": root.weather = data; break;
            case "geocode": root.geocodeItems = Object.freeze(Array.isArray(data) ? data : []); break;
            }
        }
    }
}
