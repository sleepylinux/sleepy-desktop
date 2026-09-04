// SPDX-License-Identifier: GPL-3.0-only

pragma ComponentBehavior: Bound

import QtQuick 6.0

Column {
    id: root
    required property var outputState
    spacing: 5

    Repeater {
        model: [
            {id: "launcher", label: "Apps"},
            {id: "notifications", label: "Alerts"},
            {id: "dashboard", label: "Today"},
            {id: "nexus", label: "Nexus"}
        ]
        delegate: CoreOverlayButton {
            id: triggerButton
            required property var modelData
            objectName: "overlayTrigger:" + modelData.id
            width: 46
            height: 28
            label: modelData.label
            selected: root.outputState.activeOverlay === modelData.id
            enabled: root.outputState.barVisible
            description: enabled ? "Open " + modelData.label
                : modelData.label + ", unavailable in fullscreen"
            accent: root.outputState.colors.accent || "#8ab4f8"
            foreground: root.outputState.colors.textPrimary || "#f1f3f4"
            onTriggered: root.outputState.toggleOverlay(modelData.id, triggerButton)
        }
    }
}
