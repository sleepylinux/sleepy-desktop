// SPDX-License-Identifier: GPL-3.0-only

pragma ComponentBehavior: Bound

import QtQuick 6.0

Rectangle {
    id: root

    required property var outputState
    readonly property string itemId: root.outputState.expandedTrayItemId
    readonly property var rows: root.outputState.menuRows(root.itemId)

    visible: root.itemId.length > 0 && root.outputState.barVisible
    width: 174
    height: menuColumn.implicitHeight + 24
    radius: 18
    color: root.outputState.colors.surface || "#202124"
    opacity: visible ? 0.98 : 0

    Behavior on opacity {
        NumberAnimation { duration: root.outputState.motionDuration }
    }

    Column {
        id: menuColumn
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: root.rows
            delegate: CoreMenuNode {
                required property var modelData
                node: modelData.node
                depth: modelData.depth
                trayItemId: root.itemId
                outputState: root.outputState
            }
        }
    }
}
