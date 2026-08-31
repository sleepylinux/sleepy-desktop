// SPDX-License-Identifier: GPL-3.0-only

pragma ComponentBehavior: Bound

import QtQuick 6.0

Rectangle {
    id: root

    required property var node
    required property string trayItemId
    required property var outputState
    property int depth: 0
    objectName: "trayMenuNode:" + root.node.id
    width: 150
    height: 30
    enabled: root.node.enabled && root.outputState
        && root.outputState.menuActivationSupported
    activeFocusOnTab: enabled
    Accessible.role: Accessible.Button
    Accessible.name: root.node.label
    signal clicked
    onClicked: root.outputState.activateMenuNode(root.trayItemId, root.node.id)
    Keys.onReturnPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()

    radius: 8
    color: root.enabled ? "#263238" : "#202428"
    opacity: root.enabled ? 1 : 0.55

    Text {
        anchors.fill: parent
        anchors.leftMargin: 9 + root.depth * 6
        verticalAlignment: Text.AlignVCenter
        text: root.node.label
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: root.enabled ? "#f1f3f4" : "#9aa0a6"
        font.pixelSize: 12
    }

    TapHandler {
        enabled: root.enabled
        onTapped: root.clicked()
    }
}
