pragma ComponentBehavior: Bound

import QtQuick 6.0

FocusScope {
    id: root

    required property bool active
    required property var tokens
    required property var colors
    required property var iconRegistry
    required property string iconName
    required property string accessibleName

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

    SleepyIcon {
        anchors.centerIn: parent
        iconRegistry: root.iconRegistry
        name: root.iconName
        iconColor: root.active ? root.colors.accent : root.colors.textSecondary
        iconSize: 20
        accessibleName: root.accessibleName
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.triggered()
    }

    Accessible.name: accessibleName
    Accessible.role: Accessible.Button
}
