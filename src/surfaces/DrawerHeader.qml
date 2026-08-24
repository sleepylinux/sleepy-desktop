import QtQuick 6.0

Item {
    id: root

    required property string title
    required property string subtitle
    required property string surfaceId
    required property string screenKey
    required property var surfaceController
    required property var tokens
    required property var colors

    readonly property alias closeButton: closeButton

    implicitHeight: tokens.drawerHeaderHeight

    Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Text {
            text: root.title
            color: root.colors.textPrimary
            font.family: "Inter"
            font.pixelSize: 22
            font.weight: Font.DemiBold
            font.letterSpacing: -0.3
        }

        Text {
            text: root.subtitle
            color: root.colors.textSecondary
            font.family: "Inter"
            font.pixelSize: 11
        }
    }

    FocusScope {
        id: closeButton
        objectName: "closeButton"
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        width: root.tokens.drawerCloseSize
        height: root.tokens.drawerCloseSize
        activeFocusOnTab: true

        function closeSurface() {
            root.surfaceController.close(root.surfaceId, root.screenKey);
        }

        Rectangle {
            anchors.fill: parent
            radius: 13
            color: closeButton.activeFocus ? root.colors.accentSoft
                                           : root.colors.surfaceRaised
            border.width: 1
            border.color: closeButton.activeFocus ? root.colors.accent
                                                  : root.colors.border
        }

        Item {
            anchors.centerIn: parent
            width: 14
            height: 14

            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: 2
                radius: 1
                rotation: 45
                color: root.colors.textSecondary
            }

            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: 2
                radius: 1
                rotation: -45
                color: root.colors.textSecondary
            }
        }

        Keys.onReturnPressed: event => {
            closeButton.closeSurface();
            event.accepted = true;
        }
        Keys.onSpacePressed: event => {
            closeButton.closeSurface();
            event.accepted = true;
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: closeButton.closeSurface()
        }

        Accessible.name: "Close " + root.title
        Accessible.role: Accessible.Button
    }
}
