// SPDX-License-Identifier: GPL-3.0-only
// Modified for Sleepy on 2026-08-31: typed projection of the v3 desktop snapshot.

pragma Singleton

import QtQuick 6.0

QtObject {
    id: root

    readonly property DesktopModelProjection projection: DesktopModelProjection {}
    readonly property bool available: projection.available
    readonly property string connectionState: projection.connectionState
    readonly property string diagnostic: projection.diagnostic
    readonly property var generation: projection.generation
    readonly property var snapshot: projection.snapshot
    readonly property var system: projection.system
    readonly property var compositor: projection.compositor
    readonly property var notifications: projection.notificationState
    readonly property var launcher: projection.launcher
    readonly property var calendar: projection.calendar
    readonly property var weather: projection.weather
    readonly property var appearance: projection.appearance
    readonly property var resources: projection.resources
    readonly property var utilities: projection.utilities

    readonly property var monitors: projection.monitors
    readonly property var workspaces: projection.workspaces
    readonly property var windows: projection.windows
    readonly property var accessPoints: projection.accessPoints
    readonly property var connections: projection.connections
    readonly property var bluetoothDevices: projection.bluetoothDevices
    readonly property var audioNodes: projection.audioNodes
    readonly property var audioStreams: projection.audioStreams
    readonly property var players: projection.players
    readonly property var notificationItems: projection.notifications
    readonly property var launcherEntries: projection.launcherEntries
    readonly property var trayItems: projection.trayItems
    readonly property var clipboardEntries: projection.clipboardEntries
    readonly property var calendarEvents: projection.calendarEvents
    readonly property var weatherForecast: projection.weatherForecast
    readonly property var resourceSamples: projection.resourceSamples
    readonly property var focusedMonitor: projection.focusedMonitor
    readonly property var focusedWorkspace: projection.focusedWorkspace
    readonly property var focusedWindow: projection.focusedWindow

    function own(object, key) {
        return projection.own(object, key);
    }

    function capability(section, key) {
        return projection.capability(section, key);
    }

    function capabilityData(section, key, fallback) {
        return projection.capabilityData(section, key, fallback);
    }

    function command(_family, _command, _requestId) {
        return false;
    }

    function refreshFromClient() {
        if (DesktopClient.connectionState === "ready" && DesktopClient.snapshotReceived)
            return projection.applyFullSnapshot(DesktopClient.snapshot, DesktopClient.generation);
        projection.setConnectionState(DesktopClient.connectionState, DesktopClient.diagnostic);
        return false;
    }

    function focusedWorkspaceForMonitor(monitorId) { return projection.focusedWorkspaceForMonitor(monitorId); }
    function focusedWindowForMonitor(monitorId) { return projection.focusedWindowForMonitor(monitorId); }
    function monitorHasFullscreen(monitorId) { return projection.monitorHasFullscreen(monitorId); }
    function occupiedWorkspaceIds(monitorId) { return projection.occupiedWorkspaceIds(monitorId); }
    function specialWorkspaceIds(monitorId) { return projection.specialWorkspaceIds(monitorId); }
    function capabilityAvailable(section, key) { return projection.capabilityAvailable(section, key); }
    function capabilityDiagnostic(section, key) { return projection.capabilityDiagnostic(section, key); }
    function producerAvailable(section) { return projection.producerAvailable(section); }
    function producerDiagnostic(section) { return projection.producerDiagnostic(section); }

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
