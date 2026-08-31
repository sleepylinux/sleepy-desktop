// SPDX-License-Identifier: GPL-3.0-only
// Modified for Sleepy on 2026-08-31: VPN state is projected from daemon network data.

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "DesktopCommands.js" as DesktopCommands

Singleton {
    id: root

    readonly property var connections: DesktopModel.capabilityData(
        "system", "network", {"connections": []}).connections || []
    readonly property list<Provider> providers: providerVariants.instances
    property string selectedProvider: providers.length ? providers[0].providerId : ""
    readonly property Provider selected: providers.find(p => p.providerId === selectedProvider) ?? null
    readonly property bool connected: selected !== null && selected.connected
    property bool connecting: false
    property bool disconnecting: false
    property int pingMs: 0
    readonly property var status: ({
        "state": root.connected ? "connected" : "disconnected",
        "reason": ""
    })

    function setActiveProvider(index: int): void {
        if (index >= 0 && index < root.providers.length)
            root.selectedProvider = root.providers[index].providerId;
    }

    function checkStatus(): void {}

    function refreshStats(): void {
        root.pingMs = 0;
    }

    function toggle(): void {
        if (root.connected)
            root.disconnect();
        else
            root.connect();
    }

    function connect(): bool {
        root.connecting = true;
        root.connecting = false;
        return false;
    }

    function disconnect(): bool {
        if (!root.selected)
            return false;
        root.disconnecting = true;
        const command = DesktopCommands.networkDisconnect(root.selected.providerId);
        const sent = command ? CommandClient.system(command) : false;
        root.disconnecting = false;
        return sent;
    }

    function addProvider(data: var): void {
        if (root.providers.length === 0 && data && data.name)
            root.selectedProvider = data.name;
    }

    function updateProvider(_index: int, _data: var): void {}

    function deleteProvider(index: int): void {
        if (index >= 0 && index < root.providers.length
                && root.providers[index].providerId === root.selectedProvider)
            root.selectedProvider = "";
    }

    Variants {
        id: providerVariants

        model: root.connections.filter(connection => connection.kind === "vpn")

        Provider {}
    }

    component Provider: QtObject {
        required property var modelData
        required property int index
        readonly property string providerId: modelData.id || modelData.name
        readonly property string name: modelData.name || providerId
        readonly property string displayName: modelData.name || providerId
        readonly property string iface: modelData.id || ""
        readonly property bool connected: Boolean(modelData.connected)
        readonly property var connectCmd: []
        readonly property var disconnectCmd: []
    }
}
