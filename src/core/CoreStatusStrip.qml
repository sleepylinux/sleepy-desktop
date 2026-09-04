// SPDX-License-Identifier: GPL-3.0-only

pragma ComponentBehavior: Bound

import QtQuick 6.0

Column {
    id: root

    required property var outputState
    spacing: 4

    readonly property var statuses: [
        {"id": "network", "label": "Network", "available": root.outputState.networkStatusAvailable,
            "text": root.outputState.networkStatusText},
        {"id": "bluetooth", "label": "Bluetooth", "available": root.outputState.bluetoothStatusAvailable,
            "text": root.outputState.bluetoothStatusText},
        {"id": "audio", "label": "Audio", "available": root.outputState.audioStatusAvailable,
            "text": root.outputState.audioStatusText},
        {"id": "battery", "label": "Battery", "available": root.outputState.batteryStatusAvailable,
            "text": root.outputState.batteryStatusText},
        {"id": "clock", "label": "Clock", "available": root.outputState.clockStatusAvailable,
            "text": root.outputState.clockStatusText}
    ]

    Repeater {
        model: root.statuses
        delegate: Rectangle {
            id: indicator
            required property var modelData
            objectName: "barStatus:" + modelData.id
            width: 42
            height: 22
            radius: 11
            color: modelData.available ? "#34393e" : "#25292d"
            opacity: modelData.available ? 1 : 0.58
            Accessible.role: Accessible.StaticText
            Accessible.name: modelData.label + ": " + modelData.text

            Text {
                anchors.centerIn: parent
                width: parent.width - 6
                horizontalAlignment: Text.AlignHCenter
                text: indicator.modelData.text
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: indicator.modelData.available ? "#f1f3f4" : "#9aa0a6"
                font.pixelSize: 9
            }
        }
    }
}
