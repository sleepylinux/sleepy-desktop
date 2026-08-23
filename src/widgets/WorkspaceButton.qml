import QtQuick 6.0

FocusScope {
    id: root

    required property int workspaceIndex
    required property string workspaceName
    required property bool active
    required property var tokens
    required property var colors

    signal activated(int workspaceIndex)

    activeFocusOnTab: true
    implicitWidth: 42
    implicitHeight: 42

    Keys.onReturnPressed: event => {
        root.activated(root.workspaceIndex);
        event.accepted = true;
    }
    Keys.onSpacePressed: event => {
        root.activated(root.workspaceIndex);
        event.accepted = true;
    }

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: root.active ? root.colors.accentSoft : "transparent"
        border.width: root.activeFocus ? 2 : 0
        border.color: root.colors.accent

        Behavior on color {
            ColorAnimation { duration: root.tokens.motionDuration }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: root.active ? 26 : 7
        height: root.active ? 26 : 7
        radius: root.active ? 10 : 4
        color: root.active ? root.colors.accent : root.colors.textSecondary

        Behavior on width { NumberAnimation { duration: root.tokens.motionDuration } }
        Behavior on height { NumberAnimation { duration: root.tokens.motionDuration } }

        Text {
            anchors.centerIn: parent
            visible: root.active
            text: root.workspaceIndex
            color: root.colors.shellBackground
            font.family: "Inter"
            font.pixelSize: 11
            font.weight: Font.Bold
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated(root.workspaceIndex)
    }

    Accessible.name: "Workspace " + root.workspaceName
    Accessible.role: Accessible.Button
}
