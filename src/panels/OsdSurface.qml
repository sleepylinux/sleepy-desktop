// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0

Rectangle {
    id: root
    required property var osdItem
    required property var colors
    required property var effects
    radius: 18
    color: root.colors.surface
    opacity: root.effects.raisedSurfaceOpacity
    border.color: root.colors.border
    Text {
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: root.osdItem ? root.osdItem.label : ""
        color: root.colors.textPrimary; font.pixelSize: 16
        Accessible.role: Accessible.StaticText
        Accessible.name: root.osdItem ? root.osdItem.kind + ": " + root.osdItem.label : ""
    }
}
