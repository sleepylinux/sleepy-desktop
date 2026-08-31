// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0

Item {
    id: root

    required property var desktopModel
    required property var commandClient
    required property var monitor
    property int motionDuration: 180

    readonly property alias outputId: state.outputId
    readonly property alias outputName: state.outputName
    readonly property alias workspaceIds: state.workspaceIds
    readonly property alias focusedWorkspaceId: state.focusedWorkspaceId
    readonly property alias occupiedWorkspaceIds: state.occupiedWorkspaceIds
    readonly property alias specialWorkspaceIds: state.specialWorkspaceIds
    readonly property alias barVisible: state.barVisible
    readonly property alias trayItems: state.trayItems
    readonly property alias trayActivationSupported: state.trayActivationSupported
    readonly property alias menuActivationSupported: state.menuActivationSupported
    readonly property alias trayExpandedItemId: state.expandedTrayItemId
    readonly property alias osdVisible: state.osdVisible
    readonly property alias osdKind: state.osdKind
    readonly property alias osdLevel: state.osdLevel
    readonly property alias osdMuted: state.osdMuted
    readonly property alias volumeControlAvailable: state.volumeControlAvailable
    readonly property alias muteControlAvailable: state.muteControlAvailable
    readonly property alias microphoneControlAvailable: state.microphoneControlAvailable
    readonly property alias brightnessControlAvailable: state.brightnessControlAvailable
    readonly property alias networkStatusAvailable: state.networkStatusAvailable
    readonly property alias bluetoothStatusAvailable: state.bluetoothStatusAvailable
    readonly property alias audioStatusAvailable: state.audioStatusAvailable
    readonly property alias batteryStatusAvailable: state.batteryStatusAvailable
    readonly property alias clockStatusAvailable: state.clockStatusAvailable
    readonly property alias networkStatusText: state.networkStatusText
    readonly property alias bluetoothStatusText: state.bluetoothStatusText
    readonly property alias audioStatusText: state.audioStatusText
    readonly property alias batteryStatusText: state.batteryStatusText
    readonly property alias clockStatusText: state.clockStatusText
    readonly property string barEdge: bar.edge
    readonly property bool barClips: bar.clip
    readonly property string osdPlacement: osd.placement
    readonly property bool osdClips: osd.clip
    readonly property bool trayPopupVisible: trayPopup.visible
    readonly property bool trayPopupOpen:
        state.expandedTrayItemId.length > 0 && state.barVisible

    function focusWorkspace(workspaceId) { return state.focusWorkspace(workspaceId); }
    function activateTrayItem(itemId) { return state.activateTrayItem(itemId); }
    function activateMenuNode(itemId, menuId) { return state.activateMenuNode(itemId, menuId); }
    function setOsdLevel(level) { return state.setOsdLevel(level); }
    function toggleOsdMuted() { return state.toggleOsdMuted(); }
    function setBrightness(level) { return state.setBrightness(level); }
    function openOverlay(surfaceId, focusItem) { return state.openOverlay(surfaceId, focusItem); }
    function toggleOverlay(surfaceId, focusItem) {
        return state.toggleOverlay(surfaceId, focusItem);
    }
    function closeOverlay() { state.closeOverlay(); }
    function launchEntry(desktopId) { return state.launchEntry(desktopId); }
    function launchAction(desktopId, actionId) { return state.launchAction(desktopId, actionId); }
    function setDnd(enabled) { return state.setDnd(enabled); }
    function archiveNotification(notificationId) { return state.archiveNotification(notificationId); }
    function invokeNotificationAction(notificationId, actionId) {
        return state.invokeNotificationAction(notificationId, actionId);
    }
    function setDashboardTab(tabId) { return state.setDashboardTab(tabId); }
    function controlPlayer(playerId, transport) {
        return state.controlPlayer(playerId, transport);
    }
    function setNexusTab(tabId) { return state.setNexusTab(tabId); }
    function setWifiEnabled(enabled) { return state.setWifiEnabled(enabled); }
    function scanWifi() { return state.scanWifi(); }
    function connectWifi(accessPointId) { return state.connectWifi(accessPointId); }
    function disconnectNetwork(connectionId) { return state.disconnectNetwork(connectionId); }
    function setBluetoothPowered(powered) { return state.setBluetoothPowered(powered); }
    function scanBluetooth() { return state.scanBluetooth(); }
    function pairBluetoothDevice(deviceId) { return state.pairBluetoothDevice(deviceId); }
    function connectBluetoothDevice(deviceId) { return state.connectBluetoothDevice(deviceId); }
    function disconnectBluetoothDevice(deviceId) {
        return state.disconnectBluetoothDevice(deviceId);
    }
    function setDefaultAudioNode(nodeId) { return state.setDefaultAudioNode(nodeId); }
    function setNodeVolume(nodeId, level) { return state.setNodeVolume(nodeId, level); }
    function setNodeMuted(nodeId, muted) { return state.setNodeMuted(nodeId, muted); }
    function setStreamVolume(streamId, level) {
        return state.setStreamVolume(streamId, level);
    }
    function setStreamMuted(streamId, muted) {
        return state.setStreamMuted(streamId, muted);
    }
    function applyTheme(themeId) { return state.applyTheme(themeId); }
    function applyWallpaper(wallpaperId) { return state.applyWallpaper(wallpaperId); }
    function setReducedMotion(enabled) { return state.setReducedMotion(enabled); }
    function setOpaque(enabled) { return state.setOpaque(enabled); }

    readonly property string activeOverlay: state.activeOverlay
    property alias launcherSearchText: state.launcherSearchText
    readonly property alias launcherAvailable: state.launcherAvailable
    readonly property alias notificationsAvailable: state.notificationsAvailable
    readonly property alias launcherCalculatorSupported: state.launcherCalculatorSupported
    readonly property alias launcherCommandModeSupported: state.launcherCommandModeSupported
    readonly property alias filteredLauncherEntries: state.filteredLauncherEntries
    readonly property alias notificationItems: state.notificationItems
    readonly property alias toastItems: state.toastItems
    readonly property alias dndEnabled: state.dndEnabled
    readonly property string dashboardTab: state.dashboardTab
    readonly property alias mediaAvailable: state.mediaAvailable
    readonly property alias mediaDiagnostic: state.mediaDiagnostic
    readonly property alias calendarAvailable: state.calendarAvailable
    readonly property alias calendarDiagnostic: state.calendarDiagnostic
    readonly property alias weatherAvailable: state.weatherAvailable
    readonly property alias weatherDiagnostic: state.weatherDiagnostic
    readonly property alias resourcesAvailable: state.resourcesAvailable
    readonly property alias resourcesDiagnostic: state.resourcesDiagnostic
    readonly property alias players: state.players
    readonly property alias calendarEvents: state.calendarEvents
    readonly property alias weatherForecast: state.weatherForecast
    readonly property alias resourceSamples: state.resourceSamples
    readonly property string nexusTab: state.nexusTab
    readonly property alias networkAvailable: state.networkAvailable
    readonly property alias networkDiagnostic: state.networkDiagnostic
    readonly property alias bluetoothAvailable: state.bluetoothAvailable
    readonly property alias bluetoothDiagnostic: state.bluetoothDiagnostic
    readonly property alias audioAvailable: state.audioAvailable
    readonly property alias audioDiagnostic: state.audioDiagnostic
    readonly property alias appearanceAvailable: state.appearanceAvailable
    readonly property alias appearanceDiagnostic: state.appearanceDiagnostic
    readonly property alias networkData: state.networkData
    readonly property alias accessPoints: state.accessPoints
    readonly property alias connections: state.connections
    readonly property alias bluetoothDevices: state.bluetoothDevices
    readonly property alias audioNodes: state.audioNodes
    readonly property alias audioStreams: state.audioStreams
    readonly property alias currentThemeId: state.currentThemeId
    readonly property alias currentWallpaperId: state.currentWallpaperId
    readonly property alias reducedMotion: state.reducedMotion
    readonly property alias opaque: state.opaque

    CoreOutputState {
        id: state
        desktopModel: root.desktopModel
        commandClient: root.commandClient
        monitor: root.monitor
        motionDuration: root.motionDuration
    }

    CoreBar {
        id: bar
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
            margins: 12
        }
        outputState: state
    }

    CoreOsd {
        id: osd
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: 36
        }
        outputState: state
    }

    CoreTrayPopup {
        id: trayPopup
        anchors {
            left: bar.right
            leftMargin: 10
            bottom: parent.bottom
            bottomMargin: 18
        }
        outputState: state
    }

    CoreOverlayView {
        anchors.fill: parent
        outputState: state
    }
}
