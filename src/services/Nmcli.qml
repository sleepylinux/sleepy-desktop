// SPDX-License-Identifier: GPL-3.0-only
// Modified for Sleepy on 2026-08-31: network state is daemon-published.

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property var networkCapability: DesktopModel.capabilityData(
        "system", "network", {"wifiEnabled": false, "scanning": false,
                              "accessPoints": [], "connections": []})
    readonly property bool wifiEnabled: Boolean(networkCapability.wifiEnabled)
    readonly property bool scanning: Boolean(networkCapability.scanning)
    readonly property list<AccessPoint> networks: accessPointVariants.instances
    readonly property AccessPoint active: networks.find(n => n.active) ?? null
    readonly property list<EthernetDevice> ethernetDevices: ethernetVariants.instances
    readonly property EthernetDevice activeEthernet: ethernetDevices.find(d => d.connected) ?? null
    readonly property bool hasAvailableEthernet: ethernetDevices.some(d => d.connected)
    readonly property bool isConnected: active !== null || activeEthernet !== null
    readonly property bool connecting: pendingConnection !== null
    readonly property string activeConnection: active ? active.ssid
        : activeEthernet ? activeEthernet.connection : ""
    readonly property string activeInterface: activeEthernet ? activeEthernet.iface : ""
    readonly property list<string> savedConnectionSsids: savedConnections
        .filter(c => c.kind === "wifi").map(c => c.name)
    readonly property list<string> savedConnectionNames: savedConnections.map(c => c.name)
    property var savedConnections: networkCapability.connections || []
    property var savedConnectionSecurity: ({})
    property var wirelessDeviceDetails: null
    property var ethernetDeviceDetails: null
    property string ethernetDataUsage: ""
    property string ethernetSpeed: ""
    property var pendingConnection: null

    readonly property alias connectionCheckTimer: connectionCheckTimer
    readonly property alias immediateCheckTimer: immediateCheckTimer

    signal connectionFailed(string ssid)

    function rowAccessPoints(): list<var> {
        const points = networkCapability.accessPoints || [];
        const activeNames = {};
        for (const connection of networkCapability.connections || []) {
            if (connection.connected)
                activeNames[connection.name] = true;
        }
        return points.map(point => ({
            "id": point.id,
            "ssid": point.ssid,
            "bssid": point.id,
            "strength": Math.round((point.signalLevel || 0) * 100),
            "frequency": 0,
            "active": activeNames[point.ssid] === true || activeNames[point.id] === true,
            "security": point.secured ? "secured" : ""
        }));
    }

    function rowEthernetDevices(): list<var> {
        return (networkCapability.connections || [])
            .filter(connection => connection.kind === "ethernet")
            .map(connection => ({
                "interface": connection.id,
                "type": "ethernet",
                "state": connection.connected ? "connected" : "disconnected",
                "connection": connection.name,
                "connected": Boolean(connection.connected),
                "ipAddress": "",
                "gateway": "",
                "dns": [],
                "subnet": "",
                "macAddress": "",
                "speed": ""
            }));
    }

    function findNetwork(ssid: string): var {
        return root.networks.find(network => network.ssid === ssid) ?? null;
    }

    function connectingSsid(): string {
        return root.pendingConnection ? root.pendingConnection.ssid : "";
    }

    function hasSavedProfile(ssid: string): bool {
        return root.savedConnectionSsids.indexOf(ssid) >= 0;
    }

    function savedSecurityFor(ssid: string): string {
        return root.savedConnectionSecurity[String(ssid).toLowerCase()] || "";
    }

    function securityLabel(security: string): string {
        return security && security.length ? security : qsTr("Open");
    }

    function rescanWifi(): bool {
        return CommandClient.system({
            "domain": "network",
            "action": {"type": "scanWifi"}
        });
    }

    function enableWifi(enabled: bool): bool {
        return CommandClient.system({
            "domain": "network",
            "action": {
                "type": "setWifiEnabled",
                "data": {"enabled": Boolean(enabled)}
            }
        });
    }

    function toggleWifi(): bool {
        return root.enableWifi(!root.wifiEnabled);
    }

    function connectToNetwork(ssid: string, _password: string, bssid: string,
                              callback: var): bool {
        const network = root.findNetwork(ssid);
        if (!network) {
            if (callback)
                callback({"success": false, "needsPassword": false,
                          "error": "Network is not available"});
            return false;
        }
        root.pendingConnection = {"ssid": ssid, "callback": callback || null};
        const sent = CommandClient.system({
            "domain": "network",
            "action": {
                "type": "connectWifi",
                "data": {"accessPointId": network.id || bssid || ssid}
            }
        });
        if (callback)
            callback({"success": sent, "needsPassword": false, "error": sent ? "" : "Request was not sent"});
        if (!sent) {
            root.connectionFailed(ssid);
            root.pendingConnection = null;
        }
        return sent;
    }

    function connectToNetworkWithPasswordCheck(ssid: string, _isSecure: bool,
                                               callback: var): bool {
        return root.connectToNetwork(ssid, "", "", callback);
    }

    function disconnectFromNetwork(): bool {
        const connection = (networkCapability.connections || [])
            .find(item => item.kind === "wifi" && item.connected);
        if (!connection)
            return false;
        return CommandClient.system({
            "domain": "network",
            "action": {
                "type": "disconnect",
                "data": {"connectionId": connection.id}
            }
        });
    }

    function connectEthernet(connectionName: string, ifaceName: string): bool {
        void(connectionName);
        void(ifaceName);
        return false;
    }

    function disconnectEthernet(connectionName: string): bool {
        return CommandClient.system({
            "domain": "network",
            "action": {
                "type": "disconnect",
                "data": {"connectionId": connectionName}
            }
        });
    }

    function forgetNetwork(_ssid: string): bool {
        return false;
    }

    function addHiddenNetwork(_ssid: string, _password: string, _security: string,
                              _hidden: bool, callback: var): bool {
        if (callback)
            callback({"success": false, "error": "Hidden network creation is daemon-owned"});
        return false;
    }

    function loadSavedConnections(callback: var): void {
        if (callback)
            callback(root.savedConnections);
    }

    function getNetworks(callback: var): void {
        if (callback)
            callback(root.networks);
    }

    function getWirelessDeviceDetails(_iface: string, callback: var): void {
        root.wirelessDeviceDetails = {"device": "", "state": "", "connection": ""};
        if (callback)
            callback(root.wirelessDeviceDetails);
    }

    function getEthernetInterfaces(callback: var): void {
        if (callback)
            callback(root.ethernetDevices);
    }

    function getEthernetDeviceDetails(ifaceName: string, callback: var): void {
        const device = root.ethernetDevices.find(item => item.iface === ifaceName) ?? null;
        root.ethernetDeviceDetails = device;
        if (callback)
            callback(device);
    }

    function getEthernetDataUsage(_ifaceName: string, callback: var): void {
        root.ethernetDataUsage = "";
        if (callback)
            callback("");
    }

    function getEthernetSpeed(_ifaceName: string): void {
        root.ethernetSpeed = "";
    }

    function getIpv4Config(_name: string, callback: var): void {
        if (callback)
            callback({"method": "auto", "addresses": [], "gateway": "", "dns": []});
    }

    function setIpv4Config(_name: string, _config: var, callback: var): bool {
        if (callback)
            callback({"success": false, "error": "Address configuration is daemon-owned"});
        return false;
    }

    function setAutoconnect(_ssid: string, _enabled: bool, callback: var): bool {
        if (callback)
            callback({"success": false, "error": "Connection policy is daemon-owned"});
        return false;
    }

    function syncEthernetDevices(_devices: list<var>): void {}

    onActiveChanged: root.pendingConnection = null

    Variants {
        id: accessPointVariants

        model: root.rowAccessPoints()

        AccessPoint {}
    }

    Variants {
        id: ethernetVariants

        model: root.rowEthernetDevices()

        EthernetDevice {}
    }

    Timer {
        id: connectionCheckTimer

        property int checkCount: 0
        interval: 1000
    }

    Timer {
        id: immediateCheckTimer

        property int checkCount: 0
        interval: 250
    }

    component AccessPoint: QtObject {
        required property var modelData
        readonly property string id: modelData.id || modelData.ssid
        readonly property string ssid: modelData.ssid || ""
        readonly property string bssid: modelData.bssid || id
        readonly property int strength: modelData.strength || 0
        readonly property int frequency: modelData.frequency || 0
        readonly property bool active: Boolean(modelData.active)
        readonly property string security: modelData.security || ""
        readonly property bool isSecure: security.length > 0
    }

    component EthernetDevice: QtObject {
        required property var modelData
        readonly property string iface: modelData.interface || ""
        readonly property string type: modelData.type || "ethernet"
        readonly property string state: modelData.state || "disconnected"
        readonly property string connection: modelData.connection || ""
        readonly property bool connected: Boolean(modelData.connected)
        readonly property string ipAddress: modelData.ipAddress || ""
        readonly property string gateway: modelData.gateway || ""
        readonly property var dns: modelData.dns || []
        readonly property string subnet: modelData.subnet || ""
        readonly property string macAddress: modelData.macAddress || ""
        readonly property string speed: modelData.speed || ""
    }
}
