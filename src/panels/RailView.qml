pragma ComponentBehavior: Bound

import QtQuick 6.0
import "../widgets" as Widgets

FocusScope {
    id: root

    required property var tokens
    required property var colors
    required property var artworkRegistry
    required property var surfaceController
    required property var workspaceModel
    property string timeText: "22\n24"

    readonly property int workspaceCount: workspaceRepeater.count

    signal workspaceActivated(int index)

    implicitWidth: tokens.railWidth
    implicitHeight: 720

    Rectangle {
        anchors.fill: parent
        radius: root.tokens.shellRadius
        color: root.colors.surface
        border.width: 1
        border.color: root.colors.border
    }

    Widgets.BrandMark {
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            topMargin: 15
        }
        artworkRegistry: root.artworkRegistry
    }

    Column {
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            topMargin: 80
        }
        spacing: 7

        Repeater {
            id: workspaceRepeater
            model: root.workspaceModel

            delegate: Widgets.WorkspaceButton {
                required property var modelData

                workspaceIndex: Number(modelData.index)
                workspaceName: String(modelData.name)
                active: Boolean(modelData.active)
                tokens: root.tokens
                colors: root.colors
                onActivated: index => root.workspaceActivated(index)
            }
        }
    }

    Column {
        anchors {
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
            bottomMargin: 15
        }
        spacing: 9

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.timeText
            color: root.colors.textSecondary
            horizontalAlignment: Text.AlignHCenter
            lineHeight: 0.85
            font.family: "Inter"
            font.pixelSize: 11
            font.weight: Font.Medium
            font.features: {"tnum": 1}
        }

        Widgets.StatusButton {
            objectName: "quickSettingsButton"
            active: root.surfaceController.isOpen("quickSettings")
            tokens: root.tokens
            colors: root.colors
            onTriggered: root.surfaceController.toggle("quickSettings")
        }
    }
}
