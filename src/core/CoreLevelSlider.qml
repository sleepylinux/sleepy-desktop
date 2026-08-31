// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0

Item {
    id: root

    property real value: 0
    property color accentColor: "#8ab4f8"
    property string accessibleName: "Level"
    signal moved

    implicitHeight: 40
    activeFocusOnTab: enabled
    Accessible.role: Accessible.Slider
    Accessible.name: accessibleName

    function updateFromPosition(position) {
        root.value = Math.max(0, Math.min(1, position / Math.max(1, root.width)));
        root.moved();
    }

    Keys.onLeftPressed: {
        root.value = Math.max(0, root.value - 0.05);
        root.moved();
    }
    Keys.onRightPressed: {
        root.value = Math.min(1, root.value + 0.05);
        root.moved();
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 8
        radius: 4
        color: "#3c4043"

        Rectangle {
            width: parent.width * root.value
            height: parent.height
            radius: parent.radius
            color: root.accentColor
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        onPressed: mouse => root.updateFromPosition(mouse.x)
        onPositionChanged: mouse => {
            if (pressed)
                root.updateFromPosition(mouse.x);
        }
    }
}
