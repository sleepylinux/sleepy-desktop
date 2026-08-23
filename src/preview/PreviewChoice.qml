import QtQuick 6.0

FocusScope {
    id: root

    required property string label
    required property bool selected
    required property var tokens
    required property var colors

    signal triggered

    activeFocusOnTab: true
    implicitWidth: Math.max(82, labelText.implicitWidth + 28)
    implicitHeight: 36

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
        radius: 13
        color: root.selected ? root.colors.accentSoft : root.colors.surfaceRaised
        border.width: root.activeFocus ? 2 : 1
        border.color: root.activeFocus || root.selected ? root.colors.accent : root.colors.border
    }

    Text {
        id: labelText
        anchors.centerIn: parent
        text: root.label
        color: root.selected ? root.colors.accent : root.colors.textSecondary
        font.family: "Inter"
        font.pixelSize: 11
        font.weight: Font.DemiBold
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.triggered()
    }
}
