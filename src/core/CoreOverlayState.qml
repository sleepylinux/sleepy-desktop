// SPDX-License-Identifier: GPL-3.0-only
// Derived from Caelestia v2.4.0 launcher and notification drawer behavior for Sleepy.

import QtQuick 6.0
import "../services/DesktopCommands.js" as DesktopCommands

QtObject {
    id: root

    required property var desktopModel
    required property var commandClient
    required property string outputId
    property bool surfaceAllowed: true
    property string activeSurface: ""
    property string launcherSearchText: ""
    property string dashboardTab: "overview"
    property string nexusTab: "network"
    property var returnFocusItem: null

    readonly property bool busy: Boolean(root.commandClient?.busy ?? false)
    readonly property bool overlayOpen: root.activeSurface.length > 0
    readonly property bool launcherAvailable: root.desktopModel.producerAvailable("launcher")
    readonly property string launcherDiagnostic:
        root.desktopModel.producerDiagnostic("launcher") || "Launcher unavailable"
    readonly property bool notificationsAvailable:
        root.desktopModel.producerAvailable("notifications")
    readonly property string notificationsDiagnostic:
        root.desktopModel.producerDiagnostic("notifications") || "Notifications unavailable"
    readonly property bool launcherCalculatorSupported: false
    readonly property bool launcherSchemeSupported: false
    readonly property bool launcherWallpaperSupported: false
    readonly property bool launcherCommandModeSupported: false
    readonly property bool launcherActionsSupported: false
    readonly property bool mediaAvailable:
        root.desktopModel.capabilityAvailable("system", "media")
    readonly property string mediaDiagnostic:
        root.desktopModel.capabilityDiagnostic("system", "media") || "Media unavailable"
    readonly property bool calendarAvailable:
        root.desktopModel.producerAvailable("calendar")
    readonly property string calendarDiagnostic:
        root.desktopModel.producerDiagnostic("calendar") || "Calendar unavailable"
    readonly property bool weatherAvailable:
        root.desktopModel.producerAvailable("weather")
    readonly property string weatherDiagnostic:
        root.desktopModel.producerDiagnostic("weather") || "Weather unavailable"
    readonly property bool resourcesAvailable:
        root.desktopModel.producerAvailable("resources")
    readonly property string resourcesDiagnostic:
        root.desktopModel.producerDiagnostic("resources") || "System resources unavailable"
    readonly property var players:
        root.mediaAvailable ? root.desktopModel.players : []
    readonly property var calendarEvents:
        root.calendarAvailable ? root.desktopModel.calendarEvents : []
    readonly property var weatherForecast:
        root.weatherAvailable ? root.desktopModel.weatherForecast : []
    readonly property var resourceSamples:
        root.resourcesAvailable ? root.desktopModel.resourceSamples : []
    readonly property bool networkAvailable:
        root.desktopModel.capabilityAvailable("system", "network")
    readonly property string networkDiagnostic:
        root.desktopModel.capabilityDiagnostic("system", "network") || "Network unavailable"
    readonly property bool bluetoothAvailable:
        root.desktopModel.capabilityAvailable("system", "bluetooth")
    readonly property string bluetoothDiagnostic:
        root.desktopModel.capabilityDiagnostic("system", "bluetooth") || "Bluetooth unavailable"
    readonly property bool audioAvailable:
        root.desktopModel.capabilityAvailable("system", "audio")
    readonly property string audioDiagnostic:
        root.desktopModel.capabilityDiagnostic("system", "audio") || "Audio unavailable"
    readonly property bool appearanceAvailable:
        root.desktopModel.producerAvailable("appearance")
    readonly property string appearanceDiagnostic:
        root.desktopModel.producerDiagnostic("appearance") || "Appearance unavailable"
    readonly property var networkData:
        root.networkAvailable
            ? root.desktopModel.capabilityData("system", "network", ({})) : ({})
    readonly property var bluetoothData:
        root.bluetoothAvailable
            ? root.desktopModel.capabilityData("system", "bluetooth", ({})) : ({})
    readonly property var audioData:
        root.audioAvailable
            ? root.desktopModel.capabilityData("system", "audio", ({})) : ({})
    readonly property var appearanceData:
        root.appearanceAvailable ? root.desktopModel.appearance : ({})
    readonly property var accessPoints:
        root.networkAvailable ? root.desktopModel.accessPoints : []
    readonly property var connections:
        root.networkAvailable ? root.desktopModel.connections : []
    readonly property var bluetoothDevices:
        root.bluetoothAvailable ? root.desktopModel.bluetoothDevices : []
    readonly property var audioNodes:
        root.audioAvailable ? root.desktopModel.audioNodes : []
    readonly property var audioStreams:
        root.audioAvailable ? root.desktopModel.audioStreams : []
    readonly property string currentThemeId:
        root.appearanceAvailable && typeof root.appearanceData.theme?.id === "string"
            ? root.appearanceData.theme.id : ""
    readonly property string currentWallpaperId:
        root.appearanceAvailable && typeof root.appearanceData.wallpaperId === "string"
            ? root.appearanceData.wallpaperId : ""
    readonly property bool reducedMotion:
        root.appearanceAvailable && Boolean(root.appearanceData.theme?.reducedMotion ?? false)
    readonly property bool opaque:
        root.appearanceAvailable && Boolean(root.appearanceData.theme?.opaqueFallback ?? false)
    readonly property var launcherEntries: root.desktopModel.launcherEntries
    readonly property var filteredLauncherEntries: {
        void(root.desktopModel.launcherEntries);
        const query = root.launcherSearchText.trim().toLocaleLowerCase();
        const rows = root.desktopModel.launcherEntries.filter(entry => {
            if (!query.length)
                return true;
            return String(entry.name).toLocaleLowerCase().indexOf(query) >= 0
                || String(entry.id).toLocaleLowerCase().indexOf(query) >= 0;
        });
        return rows.slice().sort((left, right) =>
            String(left.name).localeCompare(String(right.name)));
    }
    readonly property var notificationItems: root.desktopModel.notificationItems
    readonly property var toastItems: {
        void(root.desktopModel.notificationItems);
        if (!root.notificationsAvailable || root.dndEnabled)
            return [];
        return root.desktopModel.notificationItems.filter(
            item => !item.read && !item.archived);
    }
    readonly property bool dndEnabled:
        root.notificationsAvailable && Boolean(root.desktopModel.notifications?.dnd ?? false)
    readonly property bool overlayPresentationVisible:
        root.overlayOpen || root.toastItems.length > 0

    function validSurface(surfaceId) {
        return surfaceId === "launcher" || surfaceId === "notifications"
            || surfaceId === "dashboard" || surfaceId === "nexus";
    }

    function openSurface(surfaceId, focusItem) {
        if (!root.surfaceAllowed || !root.validSurface(surfaceId))
            return false;
        if (focusItem && typeof focusItem.forceActiveFocus === "function")
            root.returnFocusItem = focusItem;
        root.activeSurface = surfaceId;
        return true;
    }

    function toggleSurface(surfaceId, focusItem) {
        if (root.activeSurface === surfaceId) {
            root.closeSurface();
            return true;
        }
        return root.openSurface(surfaceId, focusItem);
    }

    function closeSurface() {
        const focusItem = root.returnFocusItem;
        root.activeSurface = "";
        root.launcherSearchText = "";
        root.dashboardTab = "overview";
        root.nexusTab = "network";
        root.returnFocusItem = null;
        if (focusItem && typeof focusItem.forceActiveFocus === "function") {
            Qt.callLater(function() {
                if (focusItem.enabled)
                    focusItem.forceActiveFocus();
            });
        }
    }

    function launcherEntry(desktopId) {
        if (typeof desktopId !== "string")
            return null;
        return root.launcherEntries.find(entry => entry.id === desktopId) || null;
    }

    function launchEntry(desktopId) {
        if (!root.launcherAvailable || root.busy || !root.launcherEntry(desktopId))
            return false;
        const command = DesktopCommands.launcherLaunch(desktopId, [], "");
        return command ? root.commandClient.launcher(command) : false;
    }

    // Strict desktop-v3 launcher rows do not expose action IDs. Keep the
    // affordance unavailable until a confirmed protocol row can authorize it.
    function launchAction(_desktopId, _actionId) {
        return false;
    }

    function setDashboardTab(tabId) {
        if (["overview", "media", "schedule", "weather", "resources"]
                .indexOf(tabId) < 0)
            return false;
        root.dashboardTab = tabId;
        return true;
    }

    function playerById(playerId) {
        if (typeof playerId !== "string")
            return null;
        return root.players.find(player => player.id === playerId) || null;
    }

    function controlPlayer(playerId, transport) {
        if (!root.mediaAvailable || root.busy || !root.playerById(playerId))
            return false;
        const command = DesktopCommands.mediaTransport(playerId, transport);
        return command ? root.commandClient.system(command) : false;
    }

    function setNexusTab(tabId) {
        if (["network", "bluetooth", "audio", "appearance", "utilities",
                "windows", "session"].indexOf(tabId) < 0)
            return false;
        root.nexusTab = tabId;
        return true;
    }

    function accessPointById(accessPointId) {
        if (typeof accessPointId !== "string")
            return null;
        return root.accessPoints.find(item => item.id === accessPointId) || null;
    }

    function connectionById(connectionId) {
        if (typeof connectionId !== "string")
            return null;
        return root.connections.find(item => item.id === connectionId) || null;
    }

    function bluetoothDeviceById(deviceId) {
        if (typeof deviceId !== "string")
            return null;
        return root.bluetoothDevices.find(item => item.id === deviceId) || null;
    }

    function audioNodeById(nodeId) {
        if (typeof nodeId !== "string")
            return null;
        return root.audioNodes.find(item => item.id === nodeId) || null;
    }

    function audioStreamById(streamId) {
        if (typeof streamId !== "string")
            return null;
        return root.audioStreams.find(item => item.id === streamId) || null;
    }

    function sendSystem(command) {
        return command ? root.commandClient.system(command) : false;
    }

    function setWifiEnabled(enabled) {
        if (!root.networkAvailable || root.busy || typeof enabled !== "boolean")
            return false;
        return root.sendSystem(DesktopCommands.networkSetWifiEnabled(enabled));
    }

    function scanWifi() {
        if (!root.networkAvailable || root.busy || !root.networkData.wifiEnabled
                || root.networkData.scanning)
            return false;
        return root.sendSystem(DesktopCommands.networkScanWifi());
    }

    function connectWifi(accessPointId) {
        if (!root.networkAvailable || root.busy || !root.networkData.wifiEnabled
                || !root.accessPointById(accessPointId))
            return false;
        return root.sendSystem(DesktopCommands.networkConnectWifi(accessPointId));
    }

    function disconnectNetwork(connectionId) {
        const connection = root.connectionById(connectionId);
        if (!root.networkAvailable || root.busy || !connection || !connection.connected)
            return false;
        return root.sendSystem(DesktopCommands.networkDisconnect(connectionId));
    }

    function setBluetoothPowered(powered) {
        if (!root.bluetoothAvailable || root.busy || typeof powered !== "boolean")
            return false;
        return root.sendSystem(DesktopCommands.bluetoothSetPowered(powered));
    }

    function scanBluetooth() {
        if (!root.bluetoothAvailable || root.busy || !root.bluetoothData.powered
                || root.bluetoothData.scanning)
            return false;
        return root.sendSystem(DesktopCommands.bluetoothScan());
    }

    function pairBluetoothDevice(deviceId) {
        const device = root.bluetoothDeviceById(deviceId);
        if (!root.bluetoothAvailable || root.busy || !root.bluetoothData.powered
                || !device || device.paired)
            return false;
        return root.sendSystem(DesktopCommands.bluetoothPair(deviceId));
    }

    function connectBluetoothDevice(deviceId) {
        const device = root.bluetoothDeviceById(deviceId);
        if (!root.bluetoothAvailable || root.busy || !root.bluetoothData.powered
                || !device || !device.paired || device.connected)
            return false;
        return root.sendSystem(DesktopCommands.bluetoothConnect(deviceId));
    }

    function disconnectBluetoothDevice(deviceId) {
        const device = root.bluetoothDeviceById(deviceId);
        if (!root.bluetoothAvailable || root.busy || !root.bluetoothData.powered
                || !device || !device.connected)
            return false;
        return root.sendSystem(DesktopCommands.bluetoothDisconnect(deviceId));
    }

    function setDefaultAudioNode(nodeId) {
        if (!root.audioAvailable || root.busy || !root.audioNodeById(nodeId))
            return false;
        return root.sendSystem(DesktopCommands.audioSetDefaultNode(nodeId));
    }

    function setNodeVolume(nodeId, level) {
        if (!root.audioAvailable || root.busy || !root.audioNodeById(nodeId))
            return false;
        return root.sendSystem(DesktopCommands.audioSetNodeVolume(nodeId, level));
    }

    function setNodeMuted(nodeId, muted) {
        if (!root.audioAvailable || root.busy || !root.audioNodeById(nodeId)
                || typeof muted !== "boolean")
            return false;
        return root.sendSystem(DesktopCommands.audioSetNodeMuted(nodeId, muted));
    }

    function setStreamVolume(streamId, level) {
        if (!root.audioAvailable || root.busy || !root.audioStreamById(streamId))
            return false;
        return root.sendSystem(DesktopCommands.audioSetStreamVolume(streamId, level));
    }

    function setStreamMuted(streamId, muted) {
        if (!root.audioAvailable || root.busy || !root.audioStreamById(streamId)
                || typeof muted !== "boolean")
            return false;
        return root.sendSystem(DesktopCommands.audioSetStreamMuted(streamId, muted));
    }

    function applyTheme(themeId) {
        if (!root.appearanceAvailable || root.busy || !root.currentThemeId.length
                || themeId !== root.currentThemeId)
            return false;
        const command = DesktopCommands.appearanceApplyTheme(themeId);
        return command ? root.commandClient.appearance(command) : false;
    }

    function applyWallpaper(wallpaperId) {
        if (!root.appearanceAvailable || root.busy || !root.currentWallpaperId.length
                || wallpaperId !== root.currentWallpaperId)
            return false;
        const command = DesktopCommands.appearanceSetWallpaper(wallpaperId);
        return command ? root.commandClient.appearance(command) : false;
    }

    function setReducedMotion(enabled) {
        if (!root.appearanceAvailable || root.busy || typeof enabled !== "boolean")
            return false;
        const command = DesktopCommands.appearanceSetReducedMotion(enabled);
        return command ? root.commandClient.appearance(command) : false;
    }

    function setOpaque(enabled) {
        if (!root.appearanceAvailable || root.busy || typeof enabled !== "boolean")
            return false;
        const command = DesktopCommands.appearanceSetOpaque(enabled);
        return command ? root.commandClient.appearance(command) : false;
    }

    function notificationById(notificationId) {
        if (typeof notificationId !== "number" || !Number.isInteger(notificationId)
                || notificationId <= 0)
            return null;
        return root.notificationItems.find(item => item.id === notificationId) || null;
    }

    function setDnd(enabled) {
        if (!root.notificationsAvailable || root.busy
                || typeof enabled !== "boolean")
            return false;
        const command = DesktopCommands.notificationSetDnd(enabled);
        return command ? root.commandClient.notification(command) : false;
    }

    function archiveNotification(notificationId) {
        const item = root.notificationById(notificationId);
        if (!root.notificationsAvailable || root.busy || !item || item.archived)
            return false;
        const command = DesktopCommands.notificationArchive(notificationId);
        return command ? root.commandClient.notification(command) : false;
    }

    function invokeNotificationAction(notificationId, actionId) {
        const item = root.notificationById(notificationId);
        if (typeof actionId !== "string")
            return false;
        const action = item?.actions?.find(candidate =>
            candidate.id === actionId && candidate.state === "available") || null;
        if (!root.notificationsAvailable || root.busy || !action)
            return false;
        const command = DesktopCommands.notificationInvokeAction(
            notificationId, actionId);
        return command ? root.commandClient.notification(command) : false;
    }

    onSurfaceAllowedChanged: {
        if (!root.surfaceAllowed)
            root.closeSurface();
    }
}
