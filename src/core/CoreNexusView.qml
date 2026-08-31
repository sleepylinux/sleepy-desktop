// SPDX-License-Identifier: GPL-3.0-only
// Strict desktop-v3 Network, Bluetooth, Audio, and Appearance controls.

pragma ComponentBehavior: Bound

import QtQuick 6.0

Column {
    id: root

    required property var outputState
    required property var colors
    readonly property alias initialFocusItem: networkTab
    spacing: 10

    Row {
        spacing: 6
        CoreOverlayButton {
            id: networkTab
            objectName: "nexusTab:network"
            label: "Network"
            selected: root.outputState.nexusTab === "network"
            accent: root.colors.accent || "#8ab4f8"
            foreground: root.colors.textPrimary || "#f1f3f4"
            onTriggered: root.outputState.setNexusTab("network")
        }
        Repeater {
            model: [
                {id: "bluetooth", label: "Bluetooth"},
                {id: "audio", label: "Audio"},
                {id: "appearance", label: "Appearance"}
            ]
            delegate: CoreOverlayButton {
                required property var modelData
                objectName: "nexusTab:" + modelData.id
                label: modelData.label
                selected: root.outputState.nexusTab === modelData.id
                accent: root.colors.accent || "#8ab4f8"
                foreground: root.colors.textPrimary || "#f1f3f4"
                onTriggered: root.outputState.setNexusTab(modelData.id)
            }
        }
    }

    Flickable {
        id: scroller
        width: parent.width
        height: Math.max(0, root.height - 48)
        clip: true
        contentWidth: width
        contentHeight: body.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        Accessible.role: Accessible.Pane
        Accessible.name: "Nexus controls"

        Column {
            id: body
            width: scroller.width
            spacing: 8

            Column {
                width: parent.width
                spacing: 8
                visible: root.outputState.nexusTab === "network"

                Text {
                    objectName: "nexusUnavailable:network"
                    visible: !root.outputState.networkAvailable
                    width: parent.width
                    text: root.outputState.networkDiagnostic
                    textFormat: Text.PlainText
                    color: "#f2b8b5"
                    wrapMode: Text.Wrap
                    Accessible.role: Accessible.StaticText
                    Accessible.name: text
                }
                Row {
                    spacing: 6
                    CoreOverlayButton {
                        objectName: "nexusWifiPower"
                        label: root.outputState.networkData.wifiEnabled ? "Wi-Fi off" : "Wi-Fi on"
                        enabled: root.outputState.networkAvailable && !root.outputState.busy
                        description: enabled ? label : root.outputState.busy
                            ? "Another desktop command is pending"
                            : root.outputState.networkDiagnostic
                        onTriggered: root.outputState.setWifiEnabled(
                            !Boolean(root.outputState.networkData.wifiEnabled))
                    }
                    CoreOverlayButton {
                        objectName: "nexusWifiScan"
                        label: root.outputState.networkData.scanning ? "Scanning" : "Scan"
                        enabled: root.outputState.networkAvailable
                            && Boolean(root.outputState.networkData.wifiEnabled)
                            && !Boolean(root.outputState.networkData.scanning)
                            && !root.outputState.busy
                        description: enabled ? "Scan confirmed Wi-Fi access points"
                            : root.outputState.busy ? "Another desktop command is pending"
                            : !root.outputState.networkAvailable
                                ? root.outputState.networkDiagnostic
                            : !root.outputState.networkData.wifiEnabled ? "Wi-Fi is off"
                            : "Wi-Fi scan is already in progress"
                        onTriggered: root.outputState.scanWifi()
                    }
                }
                Repeater {
                    model: root.outputState.accessPoints
                    delegate: Rectangle {
                        id: accessPointRow
                        required property var modelData
                        objectName: "nexusAccessPoint:" + modelData.id
                        width: body.width
                        height: 64
                        radius: 14
                        color: "#2a2e33"
                        Accessible.role: Accessible.ListItem
                        Accessible.name: modelData.ssid + ", "
                            + Math.round(modelData.signalLevel * 100) + " percent"
                        Row {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8
                            Text {
                                width: parent.width - connectButton.width - 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: accessPointRow.modelData.ssid + "  "
                                    + Math.round(accessPointRow.modelData.signalLevel * 100) + "%"
                                textFormat: Text.PlainText
                                color: root.colors.textPrimary || "#f1f3f4"
                                elide: Text.ElideRight
                            }
                            CoreOverlayButton {
                                id: connectButton
                                objectName: "nexusWifiConnect:" + accessPointRow.modelData.id
                                label: "Connect"
                                enabled: root.outputState.networkAvailable
                                    && Boolean(root.outputState.networkData.wifiEnabled)
                                    && !root.outputState.busy
                                description: enabled ? "Connect to " + accessPointRow.modelData.ssid
                                    : root.outputState.busy ? "Another desktop command is pending"
                                    : root.outputState.networkAvailable ? "Wi-Fi is off"
                                    : root.outputState.networkDiagnostic
                                onTriggered: root.outputState.connectWifi(
                                    String(accessPointRow.modelData.id))
                            }
                        }
                    }
                }
                Repeater {
                    model: root.outputState.connections.filter(item => item.connected)
                    delegate: CoreOverlayButton {
                        required property var modelData
                        objectName: "nexusNetworkDisconnect:" + modelData.id
                        label: "Disconnect " + modelData.name
                        enabled: root.outputState.networkAvailable && !root.outputState.busy
                        description: enabled ? label : "Another desktop command is pending"
                        onTriggered: root.outputState.disconnectNetwork(String(modelData.id))
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 8
                visible: root.outputState.nexusTab === "bluetooth"

                Text {
                    objectName: "nexusUnavailable:bluetooth"
                    visible: !root.outputState.bluetoothAvailable
                    width: parent.width
                    text: root.outputState.bluetoothDiagnostic
                    textFormat: Text.PlainText
                    color: "#f2b8b5"
                    wrapMode: Text.Wrap
                    Accessible.role: Accessible.StaticText
                    Accessible.name: text
                }
                Row {
                    spacing: 6
                    CoreOverlayButton {
                        objectName: "nexusBluetoothPower"
                        label: root.outputState.bluetoothData.powered
                            ? "Bluetooth off" : "Bluetooth on"
                        enabled: root.outputState.bluetoothAvailable && !root.outputState.busy
                        description: enabled ? label : root.outputState.busy
                            ? "Another desktop command is pending"
                            : root.outputState.bluetoothDiagnostic
                        onTriggered: root.outputState.setBluetoothPowered(
                            !Boolean(root.outputState.bluetoothData.powered))
                    }
                    CoreOverlayButton {
                        objectName: "nexusBluetoothScan"
                        label: root.outputState.bluetoothData.scanning ? "Scanning" : "Scan"
                        enabled: root.outputState.bluetoothAvailable
                            && Boolean(root.outputState.bluetoothData.powered)
                            && !Boolean(root.outputState.bluetoothData.scanning)
                            && !root.outputState.busy
                        description: enabled ? "Scan for Bluetooth devices"
                            : root.outputState.busy ? "Another desktop command is pending"
                            : !root.outputState.bluetoothAvailable
                                ? root.outputState.bluetoothDiagnostic
                            : !root.outputState.bluetoothData.powered ? "Bluetooth is off"
                            : "Bluetooth scan is already in progress"
                        onTriggered: root.outputState.scanBluetooth()
                    }
                }
                Repeater {
                    model: root.outputState.bluetoothDevices
                    delegate: Rectangle {
                        id: bluetoothRow
                        required property var modelData
                        objectName: "nexusBluetoothDevice:" + modelData.id
                        width: body.width
                        height: 74
                        radius: 14
                        color: "#2a2e33"
                        Accessible.role: Accessible.ListItem
                        Accessible.name: modelData.name + (modelData.connected
                            ? ", connected" : modelData.paired ? ", paired" : ", not paired")
                        Row {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8
                            Text {
                                width: parent.width - deviceAction.width - 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: bluetoothRow.modelData.name
                                textFormat: Text.PlainText
                                color: root.colors.textPrimary || "#f1f3f4"
                                elide: Text.ElideRight
                            }
                            CoreOverlayButton {
                                id: deviceAction
                                objectName: "nexusBluetoothAction:" + bluetoothRow.modelData.id
                                label: bluetoothRow.modelData.connected ? "Disconnect"
                                    : bluetoothRow.modelData.paired ? "Connect" : "Pair"
                                enabled: root.outputState.bluetoothAvailable
                                    && Boolean(root.outputState.bluetoothData.powered)
                                    && !root.outputState.busy
                                description: enabled ? label + " " + bluetoothRow.modelData.name
                                    : root.outputState.busy ? "Another desktop command is pending"
                                    : root.outputState.bluetoothAvailable ? "Bluetooth is off"
                                    : root.outputState.bluetoothDiagnostic
                                onTriggered: {
                                    if (bluetoothRow.modelData.connected)
                                        root.outputState.disconnectBluetoothDevice(
                                            String(bluetoothRow.modelData.id));
                                    else if (bluetoothRow.modelData.paired)
                                        root.outputState.connectBluetoothDevice(
                                            String(bluetoothRow.modelData.id));
                                    else
                                        root.outputState.pairBluetoothDevice(
                                            String(bluetoothRow.modelData.id));
                                }
                            }
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 8
                visible: root.outputState.nexusTab === "audio"

                Text {
                    objectName: "nexusUnavailable:audio"
                    visible: !root.outputState.audioAvailable
                    width: parent.width
                    text: root.outputState.audioDiagnostic
                    textFormat: Text.PlainText
                    color: "#f2b8b5"
                    wrapMode: Text.Wrap
                    Accessible.role: Accessible.StaticText
                    Accessible.name: text
                }
                Repeater {
                    model: root.outputState.audioNodes
                    delegate: Rectangle {
                        id: nodeRow
                        required property var modelData
                        objectName: "nexusAudioNode:" + modelData.id
                        width: body.width
                        height: 104
                        radius: 14
                        color: "#2a2e33"
                        Accessible.role: Accessible.ListItem
                        Accessible.name: modelData.name + ", "
                            + Math.round(modelData.volume * 100) + " percent"
                        Column {
                            anchors.fill: parent
                            anchors.margins: 9
                            spacing: 6
                            Text {
                                width: parent.width
                                text: nodeRow.modelData.name + "  "
                                    + Math.round(nodeRow.modelData.volume * 100) + "%"
                                textFormat: Text.PlainText
                                color: root.colors.textPrimary || "#f1f3f4"
                                elide: Text.ElideRight
                            }
                            Row {
                                spacing: 5
                                CoreOverlayButton {
                                    objectName: "nexusNodeVolumeDown:" + nodeRow.modelData.id
                                    label: "-"
                                    Accessible.name: "Decrease " + nodeRow.modelData.name + " volume"
                                    enabled: root.outputState.audioAvailable
                                        && !root.outputState.busy
                                        && nodeRow.modelData.volume > 0
                                    description: enabled ? Accessible.name
                                        : root.outputState.busy
                                            ? "Another desktop command is pending"
                                        : !root.outputState.audioAvailable
                                            ? root.outputState.audioDiagnostic
                                        : "Volume is already at minimum"
                                    onTriggered: root.outputState.setNodeVolume(
                                        String(nodeRow.modelData.id),
                                        Math.max(0, Number(nodeRow.modelData.volume) - 0.1))
                                }
                                CoreOverlayButton {
                                    objectName: "nexusNodeVolumeUp:" + nodeRow.modelData.id
                                    label: "+"
                                    Accessible.name: "Increase " + nodeRow.modelData.name + " volume"
                                    enabled: root.outputState.audioAvailable
                                        && !root.outputState.busy
                                        && nodeRow.modelData.volume < 1
                                    description: enabled ? Accessible.name
                                        : root.outputState.busy
                                            ? "Another desktop command is pending"
                                        : !root.outputState.audioAvailable
                                            ? root.outputState.audioDiagnostic
                                        : "Volume is already at maximum"
                                    onTriggered: root.outputState.setNodeVolume(
                                        String(nodeRow.modelData.id),
                                        Math.min(1, Number(nodeRow.modelData.volume) + 0.1))
                                }
                                CoreOverlayButton {
                                    objectName: "nexusNodeMute:" + nodeRow.modelData.id
                                    label: nodeRow.modelData.muted ? "Unmute" : "Mute"
                                    Accessible.name: label + " " + nodeRow.modelData.name
                                    enabled: root.outputState.audioAvailable
                                        && !root.outputState.busy
                                    description: enabled ? Accessible.name
                                        : root.outputState.busy
                                            ? "Another desktop command is pending"
                                            : root.outputState.audioDiagnostic
                                    onTriggered: root.outputState.setNodeMuted(
                                        String(nodeRow.modelData.id), !nodeRow.modelData.muted)
                                }
                                CoreOverlayButton {
                                    objectName: "nexusNodeDefault:" + nodeRow.modelData.id
                                    label: nodeRow.modelData.isDefault ? "Default" : "Use"
                                    Accessible.name: nodeRow.modelData.isDefault
                                        ? nodeRow.modelData.name + " is default"
                                        : "Use " + nodeRow.modelData.name + " as default"
                                    enabled: root.outputState.audioAvailable
                                        && !root.outputState.busy && !nodeRow.modelData.isDefault
                                    description: enabled ? Accessible.name
                                        : root.outputState.busy
                                            ? "Another desktop command is pending"
                                        : !root.outputState.audioAvailable
                                            ? root.outputState.audioDiagnostic
                                            : nodeRow.modelData.name + " is already default"
                                    onTriggered: root.outputState.setDefaultAudioNode(
                                        String(nodeRow.modelData.id))
                                }
                            }
                        }
                    }
                }
                Repeater {
                    model: root.outputState.audioStreams
                    delegate: Rectangle {
                        id: streamRow
                        required property var modelData
                        objectName: "nexusAudioStream:" + modelData.id
                        width: body.width
                        height: 92
                        radius: 14
                        color: "#2a2e33"
                        Accessible.role: Accessible.ListItem
                        Accessible.name: modelData.name + ", "
                            + Math.round(modelData.volume * 100) + " percent"
                        Column {
                            anchors.fill: parent
                            anchors.margins: 9
                            spacing: 6
                            Text {
                                width: parent.width
                                text: streamRow.modelData.name + "  "
                                    + Math.round(streamRow.modelData.volume * 100) + "%"
                                textFormat: Text.PlainText
                                color: root.colors.textPrimary || "#f1f3f4"
                                elide: Text.ElideRight
                            }
                            Row {
                                spacing: 5
                                CoreOverlayButton {
                                    objectName: "nexusStreamVolumeDown:" + streamRow.modelData.id
                                    label: "-"
                                    Accessible.name: "Decrease " + streamRow.modelData.name + " volume"
                                    enabled: root.outputState.audioAvailable
                                        && !root.outputState.busy
                                        && streamRow.modelData.volume > 0
                                    description: enabled ? Accessible.name
                                        : root.outputState.busy
                                            ? "Another desktop command is pending"
                                        : !root.outputState.audioAvailable
                                            ? root.outputState.audioDiagnostic
                                        : "Volume is already at minimum"
                                    onTriggered: root.outputState.setStreamVolume(
                                        String(streamRow.modelData.id),
                                        Math.max(0, Number(streamRow.modelData.volume) - 0.1))
                                }
                                CoreOverlayButton {
                                    objectName: "nexusStreamVolumeUp:" + streamRow.modelData.id
                                    label: "+"
                                    Accessible.name: "Increase " + streamRow.modelData.name + " volume"
                                    enabled: root.outputState.audioAvailable
                                        && !root.outputState.busy
                                        && streamRow.modelData.volume < 1
                                    description: enabled ? Accessible.name
                                        : root.outputState.busy
                                            ? "Another desktop command is pending"
                                        : !root.outputState.audioAvailable
                                            ? root.outputState.audioDiagnostic
                                        : "Volume is already at maximum"
                                    onTriggered: root.outputState.setStreamVolume(
                                        String(streamRow.modelData.id),
                                        Math.min(1, Number(streamRow.modelData.volume) + 0.1))
                                }
                                CoreOverlayButton {
                                    objectName: "nexusStreamMute:" + streamRow.modelData.id
                                    label: streamRow.modelData.muted ? "Unmute" : "Mute"
                                    Accessible.name: label + " " + streamRow.modelData.name
                                    enabled: root.outputState.audioAvailable
                                        && !root.outputState.busy
                                    description: enabled ? Accessible.name
                                        : root.outputState.busy
                                            ? "Another desktop command is pending"
                                            : root.outputState.audioDiagnostic
                                    onTriggered: root.outputState.setStreamMuted(
                                        String(streamRow.modelData.id), !streamRow.modelData.muted)
                                }
                            }
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 8
                visible: root.outputState.nexusTab === "appearance"

                Text {
                    objectName: "nexusUnavailable:appearance"
                    visible: !root.outputState.appearanceAvailable
                    width: parent.width
                    text: root.outputState.appearanceDiagnostic
                    textFormat: Text.PlainText
                    color: "#f2b8b5"
                    wrapMode: Text.Wrap
                    Accessible.role: Accessible.StaticText
                    Accessible.name: text
                }
                Text {
                    objectName: "nexusCurrentTheme"
                    visible: root.outputState.appearanceAvailable
                    width: parent.width
                    text: "Current theme: " + root.outputState.currentThemeId
                    textFormat: Text.PlainText
                    color: root.colors.textPrimary || "#f1f3f4"
                    elide: Text.ElideRight
                    Accessible.role: Accessible.StaticText
                    Accessible.name: text
                }
                Text {
                    objectName: "nexusCurrentWallpaper"
                    visible: root.outputState.appearanceAvailable
                    width: parent.width
                    text: "Current wallpaper: " + root.outputState.currentWallpaperId
                    textFormat: Text.PlainText
                    color: root.colors.textPrimary || "#f1f3f4"
                    elide: Text.ElideRight
                    Accessible.role: Accessible.StaticText
                    Accessible.name: text
                }
                Text {
                    visible: root.outputState.appearanceAvailable
                    width: parent.width
                    text: "No theme or wallpaper catalog was confirmed by desktop protocol v3."
                    textFormat: Text.PlainText
                    color: root.colors.textSecondary || "#bdc1c6"
                    wrapMode: Text.Wrap
                    Accessible.role: Accessible.StaticText
                    Accessible.name: text
                }
                Row {
                    spacing: 6
                    CoreOverlayButton {
                        objectName: "nexusApplyCurrentTheme"
                        label: "Reapply theme"
                        enabled: root.outputState.appearanceAvailable
                            && root.outputState.currentThemeId.length > 0
                            && !root.outputState.busy
                        description: enabled ? "Apply the confirmed current theme"
                            : root.outputState.busy ? "Another desktop command is pending"
                            : root.outputState.appearanceDiagnostic
                        onTriggered: root.outputState.applyTheme(
                            root.outputState.currentThemeId)
                    }
                    CoreOverlayButton {
                        objectName: "nexusApplyCurrentWallpaper"
                        label: "Reapply wallpaper"
                        enabled: root.outputState.appearanceAvailable
                            && root.outputState.currentWallpaperId.length > 0
                            && !root.outputState.busy
                        description: enabled ? "Apply the confirmed current wallpaper"
                            : root.outputState.busy ? "Another desktop command is pending"
                            : root.outputState.appearanceDiagnostic
                        onTriggered: root.outputState.applyWallpaper(
                            root.outputState.currentWallpaperId)
                    }
                }
                Row {
                    spacing: 6
                    CoreOverlayButton {
                        objectName: "nexusReducedMotion"
                        label: root.outputState.reducedMotion
                            ? "Use full motion" : "Reduce motion"
                        enabled: root.outputState.appearanceAvailable && !root.outputState.busy
                        description: enabled ? label : root.outputState.busy
                            ? "Another desktop command is pending"
                            : root.outputState.appearanceDiagnostic
                        onTriggered: root.outputState.setReducedMotion(
                            !root.outputState.reducedMotion)
                    }
                    CoreOverlayButton {
                        objectName: "nexusOpaque"
                        label: root.outputState.opaque
                            ? "Allow transparency" : "Use opaque surfaces"
                        enabled: root.outputState.appearanceAvailable && !root.outputState.busy
                        description: enabled ? label : root.outputState.busy
                            ? "Another desktop command is pending"
                            : root.outputState.appearanceDiagnostic
                        onTriggered: root.outputState.setOpaque(!root.outputState.opaque)
                    }
                }
            }
        }
    }
}
