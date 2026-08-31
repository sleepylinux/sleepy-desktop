// SPDX-License-Identifier: GPL-3.0-only
// Modified for Sleepy on 2026-08-31: typed projection of the v3 desktop snapshot.

pragma Singleton

import QtQuick 6.0
import "DesktopModelPrivate.js" as Internal

QtObject {
    id: root

    property int modelRevision: 0
    readonly property Component projectionFactory: Component { DesktopModelProjection {} }

    readonly property bool available: { void(root.modelRevision); return Internal.value("available", false); }
    readonly property string connectionState: { void(root.modelRevision); return Internal.value("connectionState", "offline"); }
    readonly property string diagnostic: { void(root.modelRevision); return Internal.value("diagnostic", "Waiting for sleepy-sessiond"); }
    readonly property var generation: { void(root.modelRevision); return Internal.value("generation", 0); }
    readonly property var snapshot: { void(root.modelRevision); return Internal.value("snapshot", Object.freeze({})); }
    readonly property var system: { void(root.modelRevision); return Internal.value("system", Object.freeze({})); }
    readonly property var compositor: { void(root.modelRevision); return Internal.value("compositor", Object.freeze({})); }
    readonly property var notifications: { void(root.modelRevision); return Internal.value("notificationState", Object.freeze({})); }
    readonly property var launcher: { void(root.modelRevision); return Internal.value("launcher", Object.freeze({})); }
    readonly property var calendar: { void(root.modelRevision); return Internal.value("calendar", Object.freeze({})); }
    readonly property var weather: { void(root.modelRevision); return Internal.value("weather", Object.freeze({})); }
    readonly property var appearance: { void(root.modelRevision); return Internal.value("appearance", Object.freeze({})); }
    readonly property var resources: { void(root.modelRevision); return Internal.value("resources", Object.freeze({})); }
    readonly property var utilities: { void(root.modelRevision); return Internal.value("utilities", Object.freeze({})); }

    readonly property var monitors: { void(root.modelRevision); return Internal.value("monitors", Object.freeze([])); }
    readonly property var workspaces: { void(root.modelRevision); return Internal.value("workspaces", Object.freeze([])); }
    readonly property var windows: { void(root.modelRevision); return Internal.value("windows", Object.freeze([])); }
    readonly property var accessPoints: { void(root.modelRevision); return Internal.value("accessPoints", Object.freeze([])); }
    readonly property var connections: { void(root.modelRevision); return Internal.value("connections", Object.freeze([])); }
    readonly property var bluetoothDevices: { void(root.modelRevision); return Internal.value("bluetoothDevices", Object.freeze([])); }
    readonly property var audioNodes: { void(root.modelRevision); return Internal.value("audioNodes", Object.freeze([])); }
    readonly property var audioStreams: { void(root.modelRevision); return Internal.value("audioStreams", Object.freeze([])); }
    readonly property var players: { void(root.modelRevision); return Internal.value("players", Object.freeze([])); }
    readonly property var notificationItems: { void(root.modelRevision); return Internal.value("notifications", Object.freeze([])); }
    readonly property var launcherEntries: { void(root.modelRevision); return Internal.value("launcherEntries", Object.freeze([])); }
    readonly property var trayItems: { void(root.modelRevision); return Internal.value("trayItems", Object.freeze([])); }
    readonly property var clipboardEntries: { void(root.modelRevision); return Internal.value("clipboardEntries", Object.freeze([])); }
    readonly property var calendarEvents: { void(root.modelRevision); return Internal.value("calendarEvents", Object.freeze([])); }
    readonly property var weatherForecast: { void(root.modelRevision); return Internal.value("weatherForecast", Object.freeze([])); }
    readonly property var resourceSamples: { void(root.modelRevision); return Internal.value("resourceSamples", Object.freeze([])); }
    readonly property var focusedMonitor: { void(root.modelRevision); return Internal.value("focusedMonitor", null); }
    readonly property var focusedWorkspace: { void(root.modelRevision); return Internal.value("focusedWorkspace", null); }
    readonly property var focusedWindow: { void(root.modelRevision); return Internal.value("focusedWindow", null); }

    function own(object, key) {
        return object && Object.prototype.hasOwnProperty.call(object, key);
    }

    function capability(section, key) {
        return Internal.capability(section, key);
    }

    function capabilityData(section, key, fallback) {
        return Internal.capabilityData(section, key, fallback);
    }

    function command(_family, _command, _requestId) {
        return false;
    }

    function refreshFromClient() {
        Internal.initialize(root.projectionFactory);
        const accepted = Internal.synchronize(DesktopClient.connectionState,
            DesktopClient.diagnostic, DesktopClient.snapshot, DesktopClient.generation,
            DesktopClient.snapshotReceived);
        root.modelRevision += 1;
        return accepted;
    }

    function focusedWorkspaceForMonitor(monitorId) { return Internal.focusedWorkspaceForMonitor(monitorId); }
    function focusedWindowForMonitor(monitorId) { return Internal.focusedWindowForMonitor(monitorId); }
    function monitorHasFullscreen(monitorId) { return Internal.monitorHasFullscreen(monitorId); }
    function occupiedWorkspaceIds(monitorId) { return Internal.occupiedWorkspaceIds(monitorId); }
    function specialWorkspaceIds(monitorId) { return Internal.specialWorkspaceIds(monitorId); }
    function capabilityAvailable(section, key) { return Internal.capabilityAvailable(section, key); }
    function capabilityDiagnostic(section, key) { return Internal.capabilityDiagnostic(section, key); }
    function producerAvailable(section) { return Internal.producerAvailable(section); }
    function producerDiagnostic(section) { return Internal.producerDiagnostic(section); }

    Component.onCompleted: root.refreshFromClient()

    readonly property Connections desktopConnections: Connections {
        target: DesktopClient
        function onEventAccepted() { root.refreshFromClient(); }
        function onConnectionStateChanged() {
            if (DesktopClient.connectionState !== "ready")
                root.refreshFromClient();
        }
    }
}
