// SPDX-License-Identifier: GPL-3.0-only
// Upstream-derived compact vertical tray with recursive menu affordances.

pragma ComponentBehavior: Bound

import QtQuick 6.0

Column {
    id: root

    required property var outputState
    spacing: 7

    Repeater {
        model: root.outputState.trayItems
        delegate: Rectangle {
            id: trayItem
            required property var modelData
            objectName: "trayMenuButton:" + modelData.id
            width: 42
            height: 42
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: "Open " + modelData.title + " menu"
            signal clicked
            onClicked: root.outputState.toggleTrayMenu(modelData.id)
            Keys.onReturnPressed: trayItem.clicked()
            Keys.onSpacePressed: trayItem.clicked()

            radius: 21
            color: trayItem.modelData.id === root.outputState.expandedTrayItemId
                ? (root.outputState.colors.accent || "#8ab4f8") : "#2d3135"

            Text {
                anchors.centerIn: parent
                text: trayItem.modelData.title.slice(0, 1).toUpperCase()
                color: "#f1f3f4"
                font.pixelSize: 15
                font.bold: true
            }

            TapHandler { onTapped: trayItem.clicked() }
        }
    }
}
