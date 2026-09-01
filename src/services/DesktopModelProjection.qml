// SPDX-License-Identifier: GPL-3.0-only
// Modified for Sleepy on 2026-08-31: stable presentation projection of confirmed v3 state.

import QtQuick 6.0

QtObject {
    id: root

    property int rowRevision: 0

    property string connectionState: "offline"
    property string diagnostic: "Waiting for sleepy-sessiond"
    property var generation: 0
    property var snapshot: Object.freeze({})

    readonly property bool available: root.connectionState === "ready"
    readonly property var system: root.snapshot.system || ({})
    readonly property var compositor: root.snapshot.compositor || ({})
    readonly property var notificationState: root.snapshot.notifications || ({})
    readonly property var launcher: root.snapshot.launcher || ({})
    readonly property var calendar: root.snapshot.calendar || ({})
    readonly property var weather: root.snapshot.weather || ({})
    readonly property var appearance: root.snapshot.appearance || ({})
    readonly property var resources: root.snapshot.resources || ({})
    readonly property var utilities: root.snapshot.utilities || ({})

    property var monitors: Object.freeze([])
    property var workspaces: Object.freeze([])
    property var windows: Object.freeze([])
    property var accessPoints: Object.freeze([])
    property var connections: Object.freeze([])
    property var bluetoothDevices: Object.freeze([])
    property var audioNodes: Object.freeze([])
    property var audioStreams: Object.freeze([])
    property var players: Object.freeze([])
    property var notifications: Object.freeze([])
    property var launcherEntries: Object.freeze([])
    property var trayItems: Object.freeze([])
    property var clipboardEntries: Object.freeze([])
    property var calendarEvents: Object.freeze([])
    property var weatherForecast: Object.freeze([])
    property var resourceSamples: Object.freeze([])

    readonly property var focusedMonitor: root.monitors.find(item => item.focused) || null
    readonly property var focusedWorkspace: root.workspaces.find(item => item.focused) || null
    readonly property var focusedWindow: root.windows.find(item => item.focused) || null

    function own(object, key) {
        return object && Object.prototype.hasOwnProperty.call(object, key);
    }

    function fallbackCapability(message) {
        const diagnostic = Object.create(null);
        diagnostic.message = message;
        const capability = Object.create(null);
        capability.status = "unavailable";
        capability.diagnostic = Object.freeze(diagnostic);
        return Object.freeze(capability);
    }

    function validCapabilityPath(section, key) {
        switch (section) {
        case "system":
            return ["network", "bluetooth", "audio", "media", "battery",
                    "brightness", "nightLight", "power", "osd", "lock"].indexOf(key) >= 0;
        case "compositor":
            return key === "hyprland";
        case "utilities":
            return ["trayItems", "clipboardEntries", "recording", "idleInhibited",
                    "gameMode", "screenshot", "colorPicker"].indexOf(key) >= 0;
        default:
            return false;
        }
    }

    function validProducerSection(section) {
        return ["notifications", "launcher", "calendar", "weather",
                "appearance", "resources"].indexOf(section) >= 0;
    }

    function capability(section, key) {
        if (!root.validCapabilityPath(section, key))
            return root.fallbackCapability("Capability path is not part of the desktop protocol");
        const container = root[section] || {};
        return root.own(container, key)
            ? container[key]
            : root.fallbackCapability("Capability has not reported");
    }

    function capabilityData(section, key, fallback) {
        const record = root.capability(section, key);
        return record && record.status === "available" && root.own(record, "data")
            ? record.data : fallback;
    }

    function capabilityAvailable(section, key) {
        return root.capability(section, key).status === "available";
    }

    function capabilityDiagnostic(section, key) {
        const record = root.capability(section, key);
        return record.diagnostic?.message || "";
    }

    function producerRecord(section) {
        if (!root.validProducerSection(section))
            return root.fallbackCapability("Producer is not part of the desktop protocol");
        const container = section === "notifications"
            ? root.notificationState : (root[section] || {});
        return container.availability || root.fallbackCapability("Producer has not reported");
    }

    function producerAvailable(section) {
        return root.producerRecord(section).status === "available";
    }

    function producerDiagnostic(section) {
        return root.producerRecord(section).diagnostic?.message || "";
    }

    function deepClone(value) {
        if (Array.isArray(value))
            return value.map(item => root.deepClone(item));
        if (value && typeof value === "object") {
            const copy = {};
            for (const key of Object.keys(value))
                copy[key] = root.deepClone(value[key]);
            return copy;
        }
        return value;
    }

    function deepFreeze(value) {
        if (!value || typeof value !== "object" || Object.isFrozen(value))
            return value;
        for (const key of Object.keys(value))
            root.deepFreeze(value[key]);
        return Object.freeze(value);
    }

    readonly property var reconcileRows: (function() {
        const cells = new WeakMap();
        const allowedKeysByCollection = Object.freeze({
            "notifications": Object.freeze([
                "schemaVersion", "id", "applicationId", "summary", "body", "urgency",
                "createdAt", "timeoutMs", "read", "archived", "actions"
            ]),
            "calendarEvents": Object.freeze([
                "id", "summary", "startsAt", "endsAt", "allDay", "sourceId", "location"
            ])
        });

        function createRow(propertyName, source) {
            const cell = {"record": root.deepFreeze(root.deepClone(source))};
            const target = {};
            const keys = allowedKeysByCollection[propertyName] || Object.keys(source);
            // Retained rows are immutable identity handles, not standalone QML notify sources.
            // Reactive bindings must also depend on the collection, which is republished below.
            for (const key of keys) {
                Object.defineProperty(target, key, {
                    "configurable": false,
                    "enumerable": true,
                    "get": function() {
                        void(root.rowRevision);
                        return cell.record[key];
                    }
                });
            }
            cells.set(target, cell);
            return Object.freeze(target);
        }

        function replaceRecord(propertyName, target, source) {
            const keyable = target !== null
                && (typeof target === "object" || typeof target === "function");
            const cell = keyable ? cells.get(target) : null;
            if (!cell || Object.keys(source).some(key => !root.own(target, key)))
                return createRow(propertyName, source);
            cell.record = root.deepFreeze(root.deepClone(source));
            return target;
        }

        return function(propertyName, records, keyName) {
            const source = Array.isArray(records) ? records : [];
            const key = keyName || "id";
            const previous = root[propertyName] || [];
            const byId = Object.create(null);
            for (const item of previous) {
                if (item && root.own(item, key))
                    byId[String(item[key])] = item;
            }

            const next = [];
            for (const record of source) {
                if (!record || !root.own(record, key))
                    continue;
                const identifier = String(record[key]);
                const item = root.own(byId, identifier) ? byId[identifier] : null;
                next.push(replaceRecord(propertyName, item, record));
            }
            root[propertyName] = Object.freeze(next);
        };
    })()

    function reconcileConfirmedLists() {
        const network = root.capabilityData("system", "network", {});
        const bluetooth = root.capabilityData("system", "bluetooth", {});
        const audio = root.capabilityData("system", "audio", {});
        const media = root.capabilityData("system", "media", {});
        const hyprland = root.capabilityData("compositor", "hyprland", {});
        const tray = root.capabilityData("utilities", "trayItems", []);
        const clipboard = root.capabilityData("utilities", "clipboardEntries", []);

        root.reconcileRows("monitors", hyprland.monitors || [], "id");
        root.reconcileRows("workspaces", hyprland.workspaces || [], "id");
        root.reconcileRows("windows", hyprland.windows || [], "id");
        root.reconcileRows("accessPoints", network.accessPoints || [], "id");
        root.reconcileRows("connections", network.connections || [], "id");
        root.reconcileRows("bluetoothDevices", bluetooth.devices || [], "id");
        root.reconcileRows("audioNodes", audio.nodes || [], "id");
        root.reconcileRows("audioStreams", audio.streams || [], "id");
        root.reconcileRows("players", media.players || [], "id");
        root.reconcileRows("notifications", root.notificationState.active || [], "id");
        root.reconcileRows("launcherEntries", root.launcher.entries || [], "id");
        root.reconcileRows("trayItems", tray, "id");
        root.reconcileRows("clipboardEntries", clipboard, "id");
        root.reconcileRows("calendarEvents", root.calendar.snapshot?.events || [], "id");
        root.reconcileRows("weatherForecast", root.weather.snapshot?.forecast || [], "at");
        root.reconcileRows("resourceSamples", root.resources.samples || [], "id");
        root.rowRevision += 1;
    }

    function applyFullSnapshot(document, confirmedGeneration) {
        if (!document || typeof document !== "object" || Array.isArray(document))
            return false;
        root.snapshot = root.deepFreeze(root.deepClone(document));
        root.generation = confirmedGeneration;
        root.connectionState = "ready";
        root.diagnostic = "";
        root.reconcileConfirmedLists();
        return true;
    }

    function applyDomainUpdate(topic, update, confirmedGeneration) {
        if (!root.available || !update || typeof update !== "object" || Array.isArray(update))
            return false;
        const next = Object.assign({}, root.snapshot);
        if (topic === "system" || topic === "utilities") {
            if (typeof update.domain !== "string" || !root.own(update, "data"))
                return false;
            const section = Object.assign({}, next[topic] || {});
            section[update.domain] = update.data;
            next[topic] = section;
        } else if (topic === "compositor") {
            if (typeof update.domain !== "string" || !root.own(update, "data"))
                return false;
            const compositorSection = Object.assign({}, next.compositor || {});
            if (update.domain === "hyprland") {
                compositorSection.hyprland = update.data;
            } else if (["monitors", "workspaces", "windows"].indexOf(update.domain) >= 0) {
                const current = compositorSection.hyprland || {};
                const currentData = current.status === "available" && current.data
                    && typeof current.data === "object" && !Array.isArray(current.data)
                    ? current.data : {"actionCapabilities": root.defaultHyprlandActionCapabilities(),
                                      "monitors": [], "workspaces": [], "windows": []};
                const data = Object.assign({}, currentData);
                data[update.domain] = update.data;
                compositorSection.hyprland = {"status": "available", "data": data};
            } else {
                return false;
            }
            next.compositor = compositorSection;
        } else if (["notifications", "launcher", "calendar", "weather",
                    "appearance", "resources"].indexOf(topic) >= 0) {
            next[topic] = update;
        } else {
            return false;
        }
        return root.applyFullSnapshot(next, confirmedGeneration);
    }

    function clearAuthorityDerivedState() {
        root.snapshot = Object.freeze({});
        root.reconcileConfirmedLists();
    }

    function defaultHyprlandActionCapabilities() {
        return Object.freeze({
            "focusWindow": false,
            "moveWindowToWorkspace": false,
            "closeWindow": false,
            "focusWorkspace": false,
            "moveWorkspaceToMonitor": false,
            "toggleFullscreen": false,
            "toggleFloating": false,
            "togglePinned": false,
            "toggleGroup": false,
            "exit": false
        });
    }

    function setConnectionState(state, message) {
        root.connectionState = state;
        root.diagnostic = message || "";
        if (state !== "ready")
            root.clearAuthorityDerivedState();
    }

    function workspaceForWindow(windowRecord) {
        if (!windowRecord)
            return null;
        return root.workspaces.find(item => item.id === windowRecord.workspaceId) || null;
    }

    function focusedWorkspaceForMonitor(monitorId) {
        return root.workspaces.find(item => item.monitorId === monitorId && item.focused) || null;
    }

    function focusedWindowForMonitor(monitorId) {
        return root.windows.find(item => {
            if (!item.focused)
                return false;
            const workspace = root.workspaceForWindow(item);
            return workspace && workspace.monitorId === monitorId;
        }) || null;
    }

    function monitorHasFullscreen(monitorId) {
        return root.windows.some(item => {
            if (!item.fullscreen)
                return false;
            const workspace = root.workspaceForWindow(item);
            return workspace && workspace.monitorId === monitorId;
        });
    }

    function occupiedWorkspaceIds(monitorId) {
        const occupied = Object.create(null);
        for (const item of root.windows)
            occupied[item.workspaceId] = true;
        return root.workspaces
            .filter(item => item.monitorId === monitorId && root.own(occupied, item.id)
                    && !String(item.name).startsWith("special:"))
            .map(item => item.id);
    }

    function specialWorkspaceIds(monitorId) {
        return root.workspaces
            .filter(item => item.monitorId === monitorId && String(item.name).startsWith("special:"))
            .map(item => item.id);
    }
}
