import QtQuick 6.0

FocusScope {
    id: root

    required property string label
    required property string iconText
    required property real value
    required property bool capabilityEnabled
    required property var tokens
    required property var colors

    signal valueRequested(real value)

    activeFocusOnTab: true
    implicitHeight: root.tokens.sliderRowHeight
    opacity: capabilityEnabled ? 1 : 0.7

    function requestDelta(delta) {
        if (root.capabilityEnabled)
            root.valueRequested(Math.max(0, Math.min(1, root.value + delta)));
    }

    Keys.onLeftPressed: event => {
        root.requestDelta(-0.05);
        event.accepted = true;
    }
    Keys.onRightPressed: event => {
        root.requestDelta(0.05);
        event.accepted = true;
    }

    Rectangle {
        anchors.fill: parent
        radius: root.tokens.innerRadius
        color: root.colors.surfaceRaised
        border.width: root.activeFocus ? 2 : 1
        border.color: root.activeFocus ? root.colors.accent : root.colors.border
    }

    Text {
        id: icon
        anchors {
            left: parent.left
            leftMargin: root.tokens.gridUnit
            verticalCenter: parent.verticalCenter
        }
        text: root.iconText
        color: root.colors.textSecondary
        font.pixelSize: 15
    }

    Column {
        anchors {
            left: icon.right
            right: percentage.left
            leftMargin: 10
            rightMargin: root.tokens.gridUnit
            verticalCenter: parent.verticalCenter
        }
        spacing: 7

        Text {
            text: root.label
            color: root.colors.textPrimary
            font.family: "Inter"
            font.pixelSize: 12
            font.weight: Font.Medium
        }

        Rectangle {
            id: track
            width: parent.width
            height: root.tokens.sliderTrackHeight
            radius: height / 2
            color: root.colors.surfaceQuiet

            Rectangle {
                width: parent.width * root.value
                height: parent.height
                radius: parent.radius
                color: root.colors.accent

                Behavior on width {
                    NumberAnimation { duration: root.tokens.motionDuration }
                }
            }

            MouseArea {
                objectName: "sliderPointerArea"
                anchors.fill: parent
                enabled: root.capabilityEnabled
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                function requestAt(pointerX) {
                    if (width <= 0)
                        return;
                    root.valueRequested(Math.max(0, Math.min(1, pointerX / width)));
                }

                onPressed: mouse => {
                    root.forceActiveFocus();
                    requestAt(mouse.x);
                }
                onPositionChanged: mouse => {
                    if (pressed)
                        requestAt(mouse.x);
                }
            }
        }
    }

    Text {
        id: percentage
        anchors {
            right: parent.right
            rightMargin: root.tokens.gridUnit
            verticalCenter: parent.verticalCenter
        }
        text: Math.round(root.value * 100) + "%"
        color: root.colors.textSecondary
        font.family: "Inter"
        font.pixelSize: 11
        font.features: {"tnum": 1}
    }
}
