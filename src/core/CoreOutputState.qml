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

    readonly property var colors: root.desktopModel.appearance?.theme?.colors || ({
        "surface": "#202124", "textPrimary": "#f1f3f4",
        "textSecondary": "#bdc1c6", "accent": "#8ab4f8", "control": "#e8eaed"
    })

    function focusWorkspace(workspaceId) {
        if (!root.compositorActions.focusWorkspace
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
}
