import QtQuick 6.0

FocusScope {
    id: root

    required property string label
    required property string detail
    required property string iconText
    required property bool active
    required property bool capabilityEnabled
    required property var tokens
    required property var colors

    signal triggered

    activeFocusOnTab: true
    implicitWidth: 144
    implicitHeight: 108
    opacity: capabilityEnabled ? 1 : 0.7

    Keys.onReturnPressed: event => {
        if (root.capabilityEnabled)
            root.triggered();
        event.accepted = true;
    }
    Keys.onSpacePressed: event => {
        if (root.capabilityEnabled)
            root.triggered();
        event.accepted = true;
    }

    Rectangle {
        anchors.fill: parent
        radius: root.tokens.innerRadius
        color: root.active ? root.colors.accentSoft : root.colors.surfaceRaised
        border.width: root.activeFocus ? 2 : 1
        border.color: root.activeFocus ? root.colors.accent : root.colors.border

        Behavior on color {
            ColorAnimation { duration: root.tokens.motionDuration }
        }
    }

    Rectangle {
        x: root.tokens.gridUnit
        y: root.tokens.gridUnit
        width: 34
        height: 34
        radius: 12
        color: root.active ? root.colors.accent : root.colors.surfaceQuiet

        Text {
            anchors.centerIn: parent
            text: root.iconText
            color: root.active ? root.colors.shellBackground : root.colors.textSecondary
            font.pixelSize: 16
            font.weight: Font.DemiBold
        }
    }

    Column {
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            margins: root.tokens.gridUnit
        }
        spacing: 2

        Text {
            text: root.label
            color: root.colors.textPrimary
            font.family: "Inter"
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        Text {
            text: root.capabilityEnabled ? root.detail : root.detail + " · view only"
            color: root.colors.textSecondary
            font.family: "Inter"
            font.pixelSize: 10
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.capabilityEnabled
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.triggered()
    }
}
