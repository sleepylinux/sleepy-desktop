// SPDX-License-Identifier: GPL-3.0-only

pragma ComponentBehavior: Bound

import QtQuick 6.0
import Quickshell

Scope {
    id: root
    required property var osdModel
    required property var tokens
    required property var colors
    required property var effects
    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: window
            required property var modelData
            readonly property string outputId: String(modelData.name)
            readonly property var item: root.osdModel.visibleFor(outputId)
            screen: modelData; visible: item !== null
            implicitWidth: 280; implicitHeight: 72
            color: "transparent"; aboveWindows: true; focusable: false
            exclusionMode: ExclusionMode.Ignore
            anchors.bottom: true
            margins.bottom: 64
            OsdSurface {
                anchors.fill: parent; radius: 18
                osdItem: window.item
                colors: root.colors
                effects: root.effects
            }
        }
    }
}
