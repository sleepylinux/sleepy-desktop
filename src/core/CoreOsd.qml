// SPDX-License-Identifier: GPL-3.0-only
// Upstream-derived bottom OSD with daemon-confirmed values and motion tokens.

import QtQuick 6.0

Rectangle {
    id: root

    required property var outputState
    readonly property string placement: "bottom-center"

    clip: true
    visible: root.outputState.osdVisible
    implicitWidth: 280
    implicitHeight: 72
    radius: 24
    color: root.outputState.colors.surface || "#202124"
    opacity: visible ? 0.96 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: root.outputState.motionDuration
            easing.type: Easing.OutCubic
        }
    }

    Text {
        anchors {
            left: parent.left
            leftMargin: 18
            verticalCenter: parent.verticalCenter
        }
        width: 96
        text: root.outputState.osdLabel
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: root.outputState.colors.textPrimary || "#f1f3f4"
        font.pixelSize: 14
    }

    CoreLevelSlider {
        id: levelSlider
        objectName: "osdLevelSlider"
        anchors {
            left: parent.left
            leftMargin: 120
            right: muteButton.visible ? muteButton.left : parent.right
            rightMargin: muteButton.visible ? 8 : 18
            verticalCenter: parent.verticalCenter
        }
        value: root.outputState.osdLevel
        enabled: root.outputState.osdKind === "volume"
            ? root.outputState.volumeControlAvailable
            : root.outputState.osdKind === "microphone"
                ? root.outputState.microphoneControlAvailable
                : root.outputState.osdKind === "brightness"
                    && root.outputState.brightnessControlAvailable
        activeFocusOnTab: enabled
        accessibleName: root.outputState.osdKind === "brightness"
            ? "Display brightness" : root.outputState.osdKind === "microphone"
                ? "Microphone level" : "Volume"
        accentColor: root.outputState.colors.accent || "#8ab4f8"
        onMoved: {
            const requested = value;
            root.outputState.setOsdLevel(requested);
            value = Qt.binding(() => root.outputState.osdLevel);
        }
    }

    Rectangle {
        id: muteButton
        objectName: "osdMuteButton"
        anchors {
            right: parent.right
            rightMargin: 12
            verticalCenter: parent.verticalCenter
        }
        width: 40
        height: 40
        visible: root.outputState.osdKind === "volume"
            || root.outputState.osdKind === "microphone"
        enabled: root.outputState.osdKind === "volume"
            ? root.outputState.muteControlAvailable
            : root.outputState.microphoneControlAvailable
        activeFocusOnTab: enabled
        Accessible.role: Accessible.Button
        Accessible.name: root.outputState.osdMuted ? "Unmute" : "Mute"
        radius: 20
        color: "#3c4043"
        signal clicked
        onClicked: root.outputState.toggleOsdMuted()
        Keys.onReturnPressed: muteButton.clicked()
        Keys.onSpacePressed: muteButton.clicked()

        Text {
            anchors.centerIn: parent
            text: root.outputState.osdMuted ? "M" : "V"
            color: root.outputState.colors.textPrimary || "#f1f3f4"
            font.pixelSize: 13
        }

        TapHandler {
            enabled: muteButton.enabled
            onTapped: muteButton.clicked()
        }
    }
}
