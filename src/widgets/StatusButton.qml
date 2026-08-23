pragma ComponentBehavior: Bound

import QtQuick 6.0

FocusScope {
    id: root

    required property bool active
    required property var tokens
    required property var colors

    signal triggered

    activeFocusOnTab: true
    implicitWidth: 42
    implicitHeight: 42

    Keys.onReturnPressed: event => {
        root.triggered();
        event.accepted = true;
    }
    Keys.onSpacePressed: event => {
        root.triggered();
        event.accepted = true;
    }

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: root.active ? root.colors.accentSoft : root.colors.surfaceRaised
        border.width: root.activeFocus ? 2 : 1
        border.color: root.activeFocus ? root.colors.accent : root.colors.border
    }

    Item {
        anchors.centerIn: parent
        width: 22
        height: 18

        Row {
            anchors.centerIn: parent
            spacing: 3

            Repeater {
                model: [8, 14, 10]

                delegate: Rectangle {
                    required property int modelData
                    width: 3
                    height: modelData
                    radius: 2
                    color: root.active ? root.colors.accent : root.colors.textSecondary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.triggered()
    }

    Accessible.name: "Quick settings"
    Accessible.role: Accessible.Button
}
