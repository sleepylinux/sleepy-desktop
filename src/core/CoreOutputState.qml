// SPDX-License-Identifier: GPL-3.0-only
// Derived from Caelestia v2.4.0 bar/workspace/tray and OSD behavior for Sleepy.

import QtQuick 6.0
import "../services/DesktopCommands.js" as DesktopCommands

QtObject {
    id: root

    required property var desktopModel
    required property var commandClient
    required property var monitor
    property int motionDuration: 180

    readonly property string outputId: String(root.monitor?.id ?? "")
    readonly property string outputName: String(root.monitor?.name ?? "")
    readonly property var workspaceRows: {
        void(root.desktopModel.workspaces);
        return root.desktopModel.workspaces.filter(
            workspace => workspace.monitorId === root.outputId);
    }
    readonly property var workspaceIds: root.workspaceRows.map(workspace => workspace.id)
    readonly property string focusedWorkspaceId: {
        void(root.desktopModel.workspaces);
        return root.desktopModel.focusedWorkspaceForMonitor(root.outputId)?.id ?? "";
    }
    readonly property var occupiedWorkspaceIds: {
        void(root.desktopModel.windows);
        return root.desktopModel.occupiedWorkspaceIds(root.outputId);
    }
    readonly property var specialWorkspaceIds: {
        void(root.desktopModel.workspaces);
        return root.desktopModel.specialWorkspaceIds(root.outputId);
    }
    readonly property bool fullscreen: {
        void(root.desktopModel.windows);
        return root.desktopModel.monitorHasFullscreen(root.outputId);
    }
    readonly property bool barVisible: !root.fullscreen

    readonly property var trayItems: root.desktopModel.trayItems
    readonly property bool trayActivationSupported: false
    readonly property bool menuActivationSupported: true
    property string expandedTrayItemId: ""

    readonly property var compositorData:
        root.desktopModel.capabilityData("compositor", "hyprland", ({}))
    readonly property var compositorActions: root.compositorData.actionCapabilities || ({})
    readonly property var networkData:
        root.desktopModel.capabilityData("system", "network", ({}))
    readonly property var bluetoothData:
        root.desktopModel.capabilityData("system", "bluetooth", ({}))
    readonly property var audioData:
        root.desktopModel.capabilityData("system", "audio", ({}))
    readonly property var batteryData:
        root.desktopModel.capabilityData("system", "battery", ({}))
    readonly property bool networkStatusAvailable:
        root.desktopModel.capabilityAvailable("system", "network")
    readonly property bool bluetoothStatusAvailable:
        root.desktopModel.capabilityAvailable("system", "bluetooth")
    readonly property bool audioStatusAvailable:
        root.desktopModel.capabilityAvailable("system", "audio")
    readonly property bool batteryStatusAvailable:
        root.desktopModel.capabilityAvailable("system", "battery")
    // Strict desktop-v3 has no clock producer. Keep the affordance visibly degraded
    // instead of creating a second local time authority in the active graph.
    readonly property bool clockStatusAvailable: false
    readonly property string clockStatusText: "--:--"
    readonly property string networkStatusText: {
        if (!root.networkStatusAvailable)
            return root.desktopModel.capabilityDiagnostic("system", "network")
                || "Network unavailable";
        const connected = (root.networkData.connections || []).find(item => item.connected);
        return connected ? connected.name : root.networkData.wifiEnabled ? "Disconnected" : "Wi-Fi off";
    }
    readonly property string bluetoothStatusText: {
        if (!root.bluetoothStatusAvailable)
            return root.desktopModel.capabilityDiagnostic("system", "bluetooth")
                || "Bluetooth unavailable";
        const connected = (root.bluetoothData.devices || []).filter(item => item.connected).length;
        return connected > 0 ? connected + " connected"
            : root.bluetoothData.powered ? "Bluetooth on" : "Bluetooth off";
    }
    readonly property string audioStatusText: {
        if (!root.audioStatusAvailable)
            return root.desktopModel.capabilityDiagnostic("system", "audio")
                || "Audio unavailable";
        const node = (root.audioData.nodes || []).find(
            candidate => candidate.kind === "output" && candidate.isDefault);
        return node ? node.muted ? "Muted" : Math.round(node.volume * 100) + "%"
            : "No output";
    }
    readonly property string batteryStatusText: {
        if (!root.batteryStatusAvailable)
            return root.desktopModel.capabilityDiagnostic("system", "battery")
                || "Battery unavailable";
        return Math.round(Number(root.batteryData.level || 0) * 100) + "%";
    }
    readonly property var defaultOutputNode: (root.audioData.nodes || []).find(
        node => node.kind === "output" && node.isDefault) || null
    readonly property var defaultInputNode: (root.audioData.nodes || []).find(
        node => node.kind === "input" && node.isDefault) || null
    readonly property var osdData:
        root.desktopModel.capabilityData("system", "osd", ({}))
    readonly property var osdEvent: {
        const current = root.osdData.current;
        return current && current.outputId === root.outputId ? current : null;
    }
    readonly property bool osdVisible: root.osdEvent !== null
    readonly property string osdKind: root.osdEvent?.kind ?? ""
    readonly property real osdLevel: root.osdEvent?.level ?? 0
    readonly property bool osdMuted: Boolean(root.osdEvent?.muted ?? false)
    readonly property string osdLabel: root.osdEvent?.label ?? ""
    readonly property bool volumeControlAvailable:
        root.desktopModel.capabilityAvailable("system", "audio")
        && root.defaultOutputNode !== null
    readonly property bool muteControlAvailable: root.volumeControlAvailable
    readonly property bool microphoneControlAvailable:
        root.desktopModel.capabilityAvailable("system", "audio")
        && root.defaultInputNode !== null
    readonly property bool brightnessControlAvailable:
        root.desktopModel.capabilityAvailable("system", "brightness")
    readonly property bool busy: Boolean(root.commandClient?.busy ?? false)

    // Launcher, notifications, dashboard, and Nexus share one local presentation state per
    // confirmed output.  Daemon-owned rows remain read-only; mutations are
    // routed by CoreOverlayState through the serialized command client.
    readonly property string activeOverlay: overlayState.activeSurface
    property alias launcherSearchText: overlayState.launcherSearchText
    readonly property alias overlayOpen: overlayState.overlayOpen
    readonly property alias overlayPresentationVisible: overlayState.overlayPresentationVisible
    readonly property alias launcherAvailable: overlayState.launcherAvailable
    readonly property alias launcherDiagnostic: overlayState.launcherDiagnostic
    readonly property alias notificationsAvailable: overlayState.notificationsAvailable
    readonly property alias notificationsDiagnostic: overlayState.notificationsDiagnostic
    readonly property alias launcherCalculatorSupported: overlayState.launcherCalculatorSupported
    readonly property alias launcherSchemeSupported: overlayState.launcherSchemeSupported
    readonly property alias launcherWallpaperSupported: overlayState.launcherWallpaperSupported
    readonly property alias launcherCommandModeSupported: overlayState.launcherCommandModeSupported
    readonly property alias launcherActionsSupported: overlayState.launcherActionsSupported
    readonly property alias filteredLauncherEntries: overlayState.filteredLauncherEntries
    readonly property alias notificationItems: overlayState.notificationItems
    readonly property alias toastItems: overlayState.toastItems
    readonly property alias dndEnabled: overlayState.dndEnabled
    readonly property string dashboardTab: overlayState.dashboardTab
    readonly property alias mediaAvailable: overlayState.mediaAvailable
    readonly property alias mediaDiagnostic: overlayState.mediaDiagnostic
    readonly property alias calendarAvailable: overlayState.calendarAvailable
    readonly property alias calendarDiagnostic: overlayState.calendarDiagnostic
    readonly property alias weatherAvailable: overlayState.weatherAvailable
    readonly property alias weatherDiagnostic: overlayState.weatherDiagnostic
    readonly property alias resourcesAvailable: overlayState.resourcesAvailable
    readonly property alias resourcesDiagnostic: overlayState.resourcesDiagnostic
    readonly property alias players: overlayState.players
    readonly property alias calendarEvents: overlayState.calendarEvents
    readonly property alias weatherForecast: overlayState.weatherForecast
    readonly property alias resourceSamples: overlayState.resourceSamples
    readonly property string nexusTab: overlayState.nexusTab
    readonly property alias networkAvailable: overlayState.networkAvailable
    readonly property alias networkDiagnostic: overlayState.networkDiagnostic
    readonly property alias bluetoothAvailable: overlayState.bluetoothAvailable
    readonly property alias bluetoothDiagnostic: overlayState.bluetoothDiagnostic
    readonly property alias audioAvailable: overlayState.audioAvailable
    readonly property alias audioDiagnostic: overlayState.audioDiagnostic
    readonly property alias appearanceAvailable: overlayState.appearanceAvailable
    readonly property alias appearanceDiagnostic: overlayState.appearanceDiagnostic
    readonly property alias accessPoints: overlayState.accessPoints
    readonly property alias connections: overlayState.connections
    readonly property alias bluetoothDevices: overlayState.bluetoothDevices
    readonly property alias audioNodes: overlayState.audioNodes
    readonly property alias audioStreams: overlayState.audioStreams
    readonly property alias currentThemeId: overlayState.currentThemeId
    readonly property alias currentWallpaperId: overlayState.currentWallpaperId
    readonly property alias reducedMotion: overlayState.reducedMotion
    readonly property alias opaque: overlayState.opaque
    readonly property var windows: root.desktopModel.windows
    readonly property var recordingState:
        root.desktopModel.capabilityData("utilities", "recording", ({"status": "inactive"}))
    readonly property bool recordingAvailable:
        root.desktopModel.capabilityAvailable("utilities", "recording")
    readonly property bool idleInhibited: Boolean(
        root.desktopModel.capabilityData("utilities", "idleInhibited", false))
    readonly property bool idleInhibitAvailable:
        root.desktopModel.capabilityAvailable("utilities", "idleInhibited")
    readonly property bool gameMode: Boolean(
        root.desktopModel.capabilityData("utilities", "gameMode", false))
    readonly property bool gameModeAvailable:
        root.desktopModel.capabilityAvailable("utilities", "gameMode")
    readonly property bool screenshotAvailable:
        root.desktopModel.capabilityAvailable("utilities", "screenshot")
    readonly property bool colorPickerAvailable:
        root.desktopModel.capabilityAvailable("utilities", "colorPicker")
    readonly property bool sessionAvailable: Boolean(root.desktopModel.available)
    property var actionFeedback: Object.freeze({})
    property string pendingActionId: ""

    readonly property var colors: root.desktopModel.appearance?.theme?.colors || ({
        "surface": "#202124", "textPrimary": "#f1f3f4",
        "textSecondary": "#bdc1c6", "accent": "#8ab4f8", "control": "#e8eaed"
    })

    function actionStatus(actionId) {
        return root.actionFeedback[String(actionId)]?.status ?? "idle";
    }

    function actionDiagnostic(actionId) {
        return root.actionFeedback[String(actionId)]?.diagnostic ?? "";
    }

    function updateActionFeedback(actionId, status, diagnostic) {
        const next = Object.assign({}, root.actionFeedback);
        next[String(actionId)] = Object.freeze({
            "status": String(status),
            "diagnostic": String(diagnostic || "")
        });
        root.actionFeedback = Object.freeze(next);
    }

    function sendTrackedAction(actionId, sender) {
        // DesktopCommandProtocol owns serialization.  Keep the presentation
        // tracker descriptive rather than inventing a second authority: test
        // sinks and future adapters may complete without protocol signals,
        // while the production client always raises busy before returning.
        if (root.busy)
            return false;
        const accepted = Boolean(sender());
        if (!accepted) {
            root.updateActionFeedback(actionId, "rejected",
                "Desktop command request was not accepted");
            return false;
        }
        root.pendingActionId = String(actionId);
        root.updateActionFeedback(actionId, "pending",
            "Pending desktop confirmation…");
        return true;
    }

    readonly property Connections commandFeedbackConnections: Connections {
        target: root.commandClient
        ignoreUnknownSignals: true

        function onCommandCompleted(_result) {
            if (!root.pendingActionId.length)
                return;
            const actionId = root.pendingActionId;
            root.pendingActionId = "";
            root.updateActionFeedback(actionId, "succeeded", "");
        }

        function onCommandFailed(message) {
            if (!root.pendingActionId.length)
                return;
            const actionId = root.pendingActionId;
            root.pendingActionId = "";
            const diagnostic = String(message || "Desktop command rejected");
            const status = diagnostic.toLocaleLowerCase().indexOf("timed out") >= 0
                ? "timeout" : "rejected";
            root.updateActionFeedback(actionId, status, diagnostic);
        }
    }

    function openOverlay(surfaceId, focusItem) {
        return overlayState.openSurface(surfaceId, focusItem);
    }
    function toggleOverlay(surfaceId, focusItem) {
        return overlayState.toggleSurface(surfaceId, focusItem);
    }
    function closeOverlay() { overlayState.closeSurface(); }
    function launchEntry(desktopId) { return overlayState.launchEntry(desktopId); }
    function launchAction(desktopId, actionId) {
        return overlayState.launchAction(desktopId, actionId);
    }
    function setDnd(enabled) { return overlayState.setDnd(enabled); }
    function archiveNotification(notificationId) {
        return overlayState.archiveNotification(notificationId);
    }
    function invokeNotificationAction(notificationId, actionId) {
        return overlayState.invokeNotificationAction(notificationId, actionId);
    }
    function setDashboardTab(tabId) { return overlayState.setDashboardTab(tabId); }
    function controlPlayer(playerId, transport) {
        const actionId = "media:" + String(playerId) + ":" + String(transport);
        return root.sendTrackedAction(actionId, function() {
            return overlayState.controlPlayer(playerId, transport);
        });
    }
    function setNexusTab(tabId) { return overlayState.setNexusTab(tabId); }
    function setWifiEnabled(enabled) { return overlayState.setWifiEnabled(enabled); }
    function scanWifi() { return overlayState.scanWifi(); }
    function connectWifi(accessPointId) { return overlayState.connectWifi(accessPointId); }
    function disconnectNetwork(connectionId) {
        return overlayState.disconnectNetwork(connectionId);
    }
    function setBluetoothPowered(powered) {
        return overlayState.setBluetoothPowered(powered);
    }
    function scanBluetooth() { return overlayState.scanBluetooth(); }
    function pairBluetoothDevice(deviceId) {
        return overlayState.pairBluetoothDevice(deviceId);
    }
    function connectBluetoothDevice(deviceId) {
        return overlayState.connectBluetoothDevice(deviceId);
    }
    function disconnectBluetoothDevice(deviceId) {
        return overlayState.disconnectBluetoothDevice(deviceId);
    }
    function setDefaultAudioNode(nodeId) {
        return overlayState.setDefaultAudioNode(nodeId);
    }
    function setNodeVolume(nodeId, level) {
        return overlayState.setNodeVolume(nodeId, level);
    }
    function setNodeMuted(nodeId, muted) {
        return overlayState.setNodeMuted(nodeId, muted);
    }
    function setStreamVolume(streamId, level) {
        return overlayState.setStreamVolume(streamId, level);
    }
    function setStreamMuted(streamId, muted) {
        return overlayState.setStreamMuted(streamId, muted);
    }
    function applyTheme(themeId) { return overlayState.applyTheme(themeId); }
    function applyWallpaper(wallpaperId) {
        return overlayState.applyWallpaper(wallpaperId);
    }
    function setReducedMotion(enabled) {
        return overlayState.setReducedMotion(enabled);
    }
    function setOpaque(enabled) { return overlayState.setOpaque(enabled); }

    readonly property list<QtObject> _implementationObjects: [
        CoreOverlayState {
            id: overlayState
            desktopModel: root.desktopModel
            commandClient: root.commandClient
            outputId: root.outputId
            surfaceAllowed: root.monitor !== null && root.barVisible
        }
    ]

    function focusWorkspace(workspaceId) {
        if (!root.barVisible || !root.compositorActions.focusWorkspace
                || !root.workspaceRows.some(workspace => workspace.id === workspaceId))
            return false;
        const command = DesktopCommands.compositor(
            "focusWorkspace", {"workspaceId": workspaceId});
        return command ? root.commandClient.compositor(command) : false;
    }

    function findMenuNode(itemId, menuId) {
        const item = root.trayItems.find(candidate => candidate.id === itemId);
        if (!item)
            return null;
        const pending = [item.menu];
        while (pending.length) {
            const node = pending.pop();
            if (node.id === menuId)
                return node;
            for (const child of node.children)
                pending.push(child);
        }
        return null;
    }

    function menuRows(itemId) {
        const item = root.trayItems.find(candidate => candidate.id === itemId);
        if (!item)
            return [];
        const rows = [];
        const pending = [{"node": item.menu, "depth": 0}];
        while (pending.length) {
            const current = pending.pop();
            rows.push(current);
            for (let index = current.node.children.length - 1; index >= 0; --index)
                pending.push({"node": current.node.children[index], "depth": current.depth + 1});
        }
        return rows;
    }

    function activateTrayItem(_itemId) {
        return false;
    }

    function toggleTrayMenu(itemId) {
        if (!root.barVisible || !root.trayItems.some(item => item.id === itemId))
            return false;
        root.expandedTrayItemId = root.expandedTrayItemId === itemId ? "" : itemId;
        return true;
    }

    onBarVisibleChanged: {
        if (!root.barVisible)
            root.expandedTrayItemId = "";
    }

    onTrayItemsChanged: {
        if (root.expandedTrayItemId.length
                && !root.trayItems.some(item => item.id === root.expandedTrayItemId))
            root.expandedTrayItemId = "";
    }

    function activateMenuNode(itemId, menuId) {
        if (!root.barVisible || root.expandedTrayItemId !== itemId)
            return false;
        const node = root.findMenuNode(itemId, menuId);
        if (!node || !node.enabled)
            return false;
        const command = DesktopCommands.utilityInvokeTrayMenu(itemId, menuId);
        return command ? root.commandClient.utility(command) : false;
    }

    function setOsdLevel(level) {
        let command = null;
        if (root.osdKind === "volume" && root.volumeControlAvailable)
            command = DesktopCommands.audioSetNodeVolume(root.defaultOutputNode.id, level);
        else if (root.osdKind === "microphone" && root.microphoneControlAvailable)
            command = DesktopCommands.audioSetNodeVolume(root.defaultInputNode.id, level);
        else if (root.osdKind === "brightness" && root.brightnessControlAvailable)
            command = DesktopCommands.displaySetBrightness(root.outputId, level);
        return command ? root.commandClient.system(command) : false;
    }

    function toggleOsdMuted() {
        let command = null;
        if (root.osdKind === "volume" && root.muteControlAvailable)
            command = DesktopCommands.audioSetNodeMuted(
                root.defaultOutputNode.id, !root.osdMuted);
        else if (root.osdKind === "microphone" && root.microphoneControlAvailable)
            command = DesktopCommands.audioSetNodeMuted(
                root.defaultInputNode.id, !root.osdMuted);
        return command ? root.commandClient.system(command) : false;
    }

    function setBrightness(level) {
        if (!root.brightnessControlAvailable)
            return false;
        const command = DesktopCommands.displaySetBrightness(root.outputId, level);
        return command ? root.commandClient.system(command) : false;
    }

    function setIdleInhibited(enabled) {
        if (!root.idleInhibitAvailable || root.busy)
            return false;
        const command = DesktopCommands.utilitySetIdleInhibited(Boolean(enabled));
        return command ? root.sendTrackedAction("utility:idleInhibit", function() {
            return root.commandClient.utility(command);
        }) : false;
    }

    function startRecording() {
        if (!root.recordingAvailable || root.busy)
            return false;
        const command = DesktopCommands.utilityStartRecording(root.outputId);
        return command ? root.sendTrackedAction("utility:recording", function() {
            return root.commandClient.utility(command);
        }) : false;
    }

    function pauseRecording() {
        return root.recordingAvailable && !root.busy
            ? root.sendTrackedAction("utility:recording", function() {
                return root.commandClient.utility(DesktopCommands.utilityPauseRecording());
            }) : false;
    }

    function stopRecording() {
        return root.recordingAvailable && !root.busy
            ? root.sendTrackedAction("utility:recording", function() {
                return root.commandClient.utility(DesktopCommands.utilityStopRecording());
            }) : false;
    }

    function takeScreenshot() {
        if (!root.screenshotAvailable || root.busy)
            return false;
        const command = DesktopCommands.utilityScreenshot(root.outputId);
        return command ? root.sendTrackedAction("utility:screenshot", function() {
            return root.commandClient.utility(command);
        }) : false;
    }

    function pickColor() {
        return root.colorPickerAvailable && !root.busy
            ? root.sendTrackedAction("utility:colorPicker", function() {
                return root.commandClient.utility(DesktopCommands.utilityPickColor());
            }) : false;
    }

    function setGameMode(enabled) {
        if (!root.gameModeAvailable || root.busy)
            return false;
        const command = DesktopCommands.utilitySetGameMode(Boolean(enabled));
        return command ? root.sendTrackedAction("utility:gameMode", function() {
            return root.commandClient.utility(command);
        }) : false;
    }

    function ownsWindow(windowId) {
        return root.windows.some(window => String(window.id) === String(windowId)
            && root.workspaceIds.indexOf(String(window.workspaceId)) >= 0);
    }

    function runWindowCommand(type, windowId, capability) {
        if (root.busy || !Boolean(root.compositorActions[capability])
                || !root.ownsWindow(windowId))
            return false;
        const command = DesktopCommands.compositor(type, {"windowId": String(windowId)});
        const actionNames = ({
            "focusWindow": "focus", "closeWindow": "close",
            "toggleFullscreen": "fullscreen", "toggleFloating": "floating",
            "togglePinned": "pinned", "toggleGroup": "group"
        });
        const actionId = "window:" + String(windowId) + ":" + actionNames[type];
        return command ? root.sendTrackedAction(actionId, function() {
            return root.commandClient.compositor(command);
        }) : false;
    }

    function focusWindow(windowId) {
        return root.runWindowCommand("focusWindow", windowId, "focusWindow");
    }
    function closeWindow(windowId) {
        return root.runWindowCommand("closeWindow", windowId, "closeWindow");
    }
    function toggleWindowFullscreen(windowId) {
        return root.runWindowCommand("toggleFullscreen", windowId, "toggleFullscreen");
    }
    function toggleWindowFloating(windowId) {
        return root.runWindowCommand("toggleFloating", windowId, "toggleFloating");
    }
    function toggleWindowPinned(windowId) {
        return root.runWindowCommand("togglePinned", windowId, "togglePinned");
    }
    function toggleWindowGroup(windowId) {
        return root.runWindowCommand("toggleGroup", windowId, "toggleGroup");
    }

    function moveWindowToWorkspace(windowId, workspaceId) {
        const window = root.windows.find(
            candidate => String(candidate.id) === String(windowId)) || null;
        if (root.busy || !root.compositorActions.moveWindowToWorkspace
                || !root.ownsWindow(windowId) || !window
                || root.workspaceIds.indexOf(String(workspaceId)) < 0
                || String(window.workspaceId) === String(workspaceId))
            return false;
        const command = DesktopCommands.compositor("moveWindowToWorkspace", {
            "windowId": String(windowId), "workspaceId": String(workspaceId)});
        const actionId = "window:" + String(windowId) + ":move:"
            + String(workspaceId);
        return command ? root.sendTrackedAction(actionId, function() {
            return root.commandClient.compositor(command);
        }) : false;
    }

    function performSession(action) {
        if (!root.sessionAvailable || root.busy)
            return false;
        const command = DesktopCommands.session(action);
        return command ? root.sendTrackedAction("session:" + String(action), function() {
            return root.commandClient.session(command);
        }) : false;
    }
}
