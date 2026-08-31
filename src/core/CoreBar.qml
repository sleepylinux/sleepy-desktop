// SPDX-License-Identifier: GPL-3.0-only
// Derived from Caelestia v2.4.0's clipped vertical-left workspace/tray composition.

pragma ComponentBehavior: Bound

import QtQuick 6.0

Rectangle {
    id: root

    required property var outputState
    readonly property string edge: "left"
    property bool shown: root.outputState.barVisible

    clip: true
    implicitWidth: root.shown ? 64 : 0
    implicitHeight: 720
    radius: 24
    color: root.outputState.colors.surface || "#202124"

    Behavior on implicitWidth {
        NumberAnimation {
            duration: root.outputState.motionDuration
            easing.type: Easing.OutCubic
        }
    }

    Column {
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            topMargin: 72
        }
        spacing: 7

        Repeater {
            id: workspaceRepeater
            model: root.outputState.workspaceRows
            delegate: Rectangle {
                id: workspaceButton
                required property var modelData
                readonly property bool focused: modelData.id === root.outputState.focusedWorkspaceId
                readonly property bool occupied:
                    root.outputState.occupiedWorkspaceIds.indexOf(modelData.id) >= 0
                readonly property bool special:
                    root.outputState.specialWorkspaceIds.indexOf(modelData.id) >= 0

                objectName: "workspace:" + modelData.id
                width: 42
                height: special ? 34 : 42
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: "Workspace " + modelData.name
                opacity: special ? 0.76 : 1
                signal clicked
                onClicked: root.outputState.focusWorkspace(modelData.id)
                Keys.onReturnPressed: workspaceButton.clicked()
                Keys.onSpacePressed: workspaceButton.clicked()

                radius: height / 2
                color: workspaceButton.focused
                    ? (root.outputState.colors.accent || "#8ab4f8")
                    : workspaceButton.occupied ? "#3c4043" : "#262a2e"

                Behavior on color {
                    ColorAnimation { duration: root.outputState.motionDuration }
                }

                Text {
                    anchors.centerIn: parent
                    text: workspaceButton.modelData.name.replace(/^special:/, "")
                    color: workspaceButton.focused ? "#101418" : "#f1f3f4"
                    font.pixelSize: 12
                    font.bold: workspaceButton.focused
                }

                TapHandler { onTapped: workspaceButton.clicked() }
            }
        }
    }

    Column {
        anchors {
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
            bottomMargin: 18
        }
        spacing: 8

        CoreStatusStrip { outputState: root.outputState }
        CoreTray { outputState: root.outputState }
    }
}
