pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Sleepy.Config
import qs.components

Item {
    id: root

    required property var screen
    required property var client

    Layout.preferredWidth: 360
    Layout.fillHeight: true

    StyledClippingRect {
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        color: Colours.tPalette.m3surfaceContainer
        radius: Tokens.rounding.medium

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width - Tokens.padding.large * 2, 320)
            spacing: Tokens.spacing.medium

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: "preview_off"
                color: Colours.palette.m3outline
                fontStyle: Tokens.font.icon.builders.extraLarge.scale(2).build()
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTr("Preview unavailable: desktop protocol v3 provides no safe preview handle")
                color: Colours.palette.m3outline
                font: Tokens.font.body.large
            }
        }
    }
}
