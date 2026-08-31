// SPDX-License-Identifier: GPL-3.0-only
// Modified for Sleepy on 2026-08-31: typed projection of the v3 desktop snapshot.

pragma Singleton

import QtQuick 6.0

QtObject {
    id: root

    property int modelRevision: 0
    readonly property Component projectionFactory: Component { DesktopModelProjection {} }
    readonly property var modelFacade: (function(factory) {
        const projection = factory.createObject(null);
        const listeners = [];
        const readableValues = Object.freeze([
            "available", "connectionState", "diagnostic", "generation", "snapshot",
            "system", "compositor", "notificationState", "launcher", "calendar",
            "weather", "appearance", "resources", "utilities", "monitors", "workspaces",
            "windows", "accessPoints", "connections", "bluetoothDevices", "audioNodes",
            "audioStreams", "players", "notifications", "launcherEntries", "trayItems",
            "clipboardEntries", "calendarEvents", "weatherForecast", "resourceSamples",
            "focusedMonitor", "focusedWorkspace", "focusedWindow"
        ]);

        function notify() {
            for (const listener of listeners)
                listener();
        }

        return Object.freeze({
            "value": function(name, fallback) {
                return readableValues.indexOf(name) >= 0 && projection[name] !== undefined
                    ? projection[name] : fallback;
            },
            "capability": function(section, key) { return projection.capability(section, key); },
            "capabilityData": function(section, key, fallback) {
                return projection.capabilityData(section, key, fallback);
            },
            "focusedWorkspaceForMonitor": function(monitorId) {
                return projection.focusedWorkspaceForMonitor(monitorId);
            },
            "focusedWindowForMonitor": function(monitorId) {
                return projection.focusedWindowForMonitor(monitorId);
            },
            "monitorHasFullscreen": function(monitorId) {
                return projection.monitorHasFullscreen(monitorId);
            },
            "occupiedWorkspaceIds": function(monitorId) {
                return projection.occupiedWorkspaceIds(monitorId);
            },
            "specialWorkspaceIds": function(monitorId) {
                return projection.specialWorkspaceIds(monitorId);
            },
            "capabilityAvailable": function(section, key) {
                return projection.capabilityAvailable(section, key);
            },
            "capabilityDiagnostic": function(section, key) {
                return projection.capabilityDiagnostic(section, key);
            },
            "producerAvailable": function(section) {
                return projection.producerAvailable(section);
            },
            "producerDiagnostic": function(section) {
                return projection.producerDiagnostic(section);
            },
            "subscribe": function(listener) {
                if (typeof listener === "function" && listeners.indexOf(listener) < 0)
                    listeners.push(listener);
            },
            "synchronize": function() {
                let accepted = false;
                if (DesktopClient.connectionState === "ready" && DesktopClient.snapshotReceived)
                    accepted = projection.applyFullSnapshot(
                        DesktopClient.snapshot, DesktopClient.generation);
                else
                    projection.setConnectionState(
                        DesktopClient.connectionState, DesktopClient.diagnostic);
                notify();
                return accepted;
            }
        });
    })(root.projectionFactory)

    readonly property bool available: { void(root.modelRevision); return root.modelFacade.value("available", false); }
    readonly property string connectionState: { void(root.modelRevision); return root.modelFacade.value("connectionState", "offline"); }
    readonly property string diagnostic: { void(root.modelRevision); return root.modelFacade.value("diagnostic", "Waiting for sleepy-sessiond"); }
    readonly property var generation: { void(root.modelRevision); return root.modelFacade.value("generation", 0); }
    readonly property var snapshot: { void(root.modelRevision); return root.modelFacade.value("snapshot", Object.freeze({})); }
    readonly property var system: { void(root.modelRevision); return root.modelFacade.value("system", Object.freeze({})); }
    readonly property var compositor: { void(root.modelRevision); return root.modelFacade.value("compositor", Object.freeze({})); }
    readonly property var notifications: { void(root.modelRevision); return root.modelFacade.value("notificationState", Object.freeze({})); }
    readonly property var launcher: { void(root.modelRevision); return root.modelFacade.value("launcher", Object.freeze({})); }
    readonly property var calendar: { void(root.modelRevision); return root.modelFacade.value("calendar", Object.freeze({})); }
    readonly property var weather: { void(root.modelRevision); return root.modelFacade.value("weather", Object.freeze({})); }
    readonly property var appearance: { void(root.modelRevision); return root.modelFacade.value("appearance", Object.freeze({})); }
    readonly property var resources: { void(root.modelRevision); return root.modelFacade.value("resources", Object.freeze({})); }
    readonly property var utilities: { void(root.modelRevision); return root.modelFacade.value("utilities", Object.freeze({})); }

    readonly property var monitors: { void(root.modelRevision); return root.modelFacade.value("monitors", Object.freeze([])); }
    readonly property var workspaces: { void(root.modelRevision); return root.modelFacade.value("workspaces", Object.freeze([])); }
    readonly property var windows: { void(root.modelRevision); return root.modelFacade.value("windows", Object.freeze([])); }
    readonly property var accessPoints: { void(root.modelRevision); return root.modelFacade.value("accessPoints", Object.freeze([])); }
    readonly property var connections: { void(root.modelRevision); return root.modelFacade.value("connections", Object.freeze([])); }
    readonly property var bluetoothDevices: { void(root.modelRevision); return root.modelFacade.value("bluetoothDevices", Object.freeze([])); }
    readonly property var audioNodes: { void(root.modelRevision); return root.modelFacade.value("audioNodes", Object.freeze([])); }
    readonly property var audioStreams: { void(root.modelRevision); return root.modelFacade.value("audioStreams", Object.freeze([])); }
    readonly property var players: { void(root.modelRevision); return root.modelFacade.value("players", Object.freeze([])); }
    readonly property var notificationItems: { void(root.modelRevision); return root.modelFacade.value("notifications", Object.freeze([])); }
    readonly property var launcherEntries: { void(root.modelRevision); return root.modelFacade.value("launcherEntries", Object.freeze([])); }
    readonly property var trayItems: { void(root.modelRevision); return root.modelFacade.value("trayItems", Object.freeze([])); }
    readonly property var clipboardEntries: { void(root.modelRevision); return root.modelFacade.value("clipboardEntries", Object.freeze([])); }
    readonly property var calendarEvents: { void(root.modelRevision); return root.modelFacade.value("calendarEvents", Object.freeze([])); }
    readonly property var weatherForecast: { void(root.modelRevision); return root.modelFacade.value("weatherForecast", Object.freeze([])); }
    readonly property var resourceSamples: { void(root.modelRevision); return root.modelFacade.value("resourceSamples", Object.freeze([])); }
    readonly property var focusedMonitor: { void(root.modelRevision); return root.modelFacade.value("focusedMonitor", null); }
    readonly property var focusedWorkspace: { void(root.modelRevision); return root.modelFacade.value("focusedWorkspace", null); }
    readonly property var focusedWindow: { void(root.modelRevision); return root.modelFacade.value("focusedWindow", null); }

    function own(object, key) {
        return object && Object.prototype.hasOwnProperty.call(object, key);
    }

    function capability(section, key) {
        return root.modelFacade.capability(section, key);
    }

    function capabilityData(section, key, fallback) {
        return root.modelFacade.capabilityData(section, key, fallback);
    }

    function command(_family, _command, _requestId) {
        return false;
    }

    function refreshFromClient() {
        return root.modelFacade.synchronize();
    }

    function focusedWorkspaceForMonitor(monitorId) { return root.modelFacade.focusedWorkspaceForMonitor(monitorId); }
    function focusedWindowForMonitor(monitorId) { return root.modelFacade.focusedWindowForMonitor(monitorId); }
    function monitorHasFullscreen(monitorId) { return root.modelFacade.monitorHasFullscreen(monitorId); }
    function occupiedWorkspaceIds(monitorId) { return root.modelFacade.occupiedWorkspaceIds(monitorId); }
    function specialWorkspaceIds(monitorId) { return root.modelFacade.specialWorkspaceIds(monitorId); }
    function capabilityAvailable(section, key) { return root.modelFacade.capabilityAvailable(section, key); }
    function capabilityDiagnostic(section, key) { return root.modelFacade.capabilityDiagnostic(section, key); }
    function producerAvailable(section) { return root.modelFacade.producerAvailable(section); }
    function producerDiagnostic(section) { return root.modelFacade.producerDiagnostic(section); }

    Component.onCompleted: {
        root.modelFacade.subscribe(function() { root.modelRevision += 1; });
        root.refreshFromClient();
    }

    readonly property Connections desktopConnections: Connections {
        target: DesktopClient
        function onEventAccepted() { root.refreshFromClient(); }
        function onConnectionStateChanged() {
            if (DesktopClient.connectionState !== "ready")
                root.refreshFromClient();
        }
    }
}
