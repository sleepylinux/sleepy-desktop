// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property int inputLength
    required property int authState
    property string clockText: Qt.formatTime(new Date(), "hh:mm")
    property var media: ({})
    property var weather: ({})
    property var notificationSummary: ({})
    property var resources: ({})
    property size outputSize: Qt.size(width, height)

    signal authenticateRequested()

    readonly property color surface: "#dfe3eb"
    readonly property color onSurface: "#171c23"
    readonly property color surfaceContainer: "#bcc4cf"
    readonly property color secondaryContainer: "#c4c6e9"
    readonly property color error: "#ba1a1a"

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.clockText = Qt.formatTime(new Date(), "hh:mm")
    }

    Rectangle {
        anchors.fill: parent
        color: "#141820"

        gradient: Gradient {
            GradientStop { position: 0; color: "#222a37" }
            GradientStop { position: 0.52; color: "#11161e" }
            GradientStop { position: 1; color: "#292335" }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#65000000"
    }

    Item {
        id: lockContent
        anchors.centerIn: parent
        width: Math.min(root.width - 48, root.height * 0.8 * 1.62)
        height: Math.min(root.height - 48, root.height * 0.8)
        scale: 0.15
        rotation: -18
        opacity: 0

        Rectangle {
            anchors.fill: parent
            radius: 42
            color: root.surface
            border.width: 1
            border.color: "#42ffffff"
        }

        GridLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 28
            columns: 3
            columnSpacing: 24
            opacity: 0
            scale: 0.92

            ColumnLayout {
                Layout.preferredWidth: lockContent.width * 0.27
                Layout.fillHeight: true
                spacing: 14

                Text {
                    text: weather.temperature || "—°"
                    color: root.onSurface
                    font.pixelSize: 46
                    font.weight: Font.DemiBold
                }
                Text {
                    text: weather.description || qsTr("Sleepy weather")
                    color: "#5a616c"
                    font.pixelSize: 17
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 118
                    radius: 25
                    color: root.secondaryContainer

                    Column {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 7
                        Text { text: qsTr("NOW PLAYING"); color: "#53566f"; font.pixelSize: 11; font.weight: Font.Bold }
                        Text { width: parent.width; elide: Text.ElideRight; text: media.title || qsTr("Nothing playing"); color: root.onSurface; font.pixelSize: 18 }
                        Text { width: parent.width; elide: Text.ElideRight; text: media.artist || "Sleepy Linux"; color: "#5a616c"; font.pixelSize: 14 }
                    }
                }
                Item { Layout.fillHeight: true }
                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: notificationSummary.text || qsTr("Notifications appear here")
                    color: "#5a616c"
                    font.pixelSize: 14
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 14

                Item { Layout.fillHeight: true }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.clockText
                    color: root.onSurface
                    font.pixelSize: Math.max(72, lockContent.height * 0.15)
                    font.weight: Font.Light
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDate(new Date(), "dddd  •  d MMM").toUpperCase()
                    color: "#59616c"
                    font.pixelSize: 16
                    font.letterSpacing: 1.2
                }
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 28
                    width: 116
                    height: 116
                    radius: 38
                    color: root.secondaryContainer

                    Text {
                        anchors.centerIn: parent
                        text: "☾"
                        color: "#3e4160"
                        font.pixelSize: 62
                    }
                }
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 18
                    width: Math.min(360, lockContent.width * 0.38)
                    height: 58
                    radius: 29
                    color: root.authState === 3 || root.authState === 4 ? "#ffffdad6" : root.surfaceContainer
                    border.width: 2
                    border.color: root.authState === 3 || root.authState === 4 ? root.error : "transparent"

                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        Repeater {
                            model: Math.min(root.inputLength, 24)
                            Rectangle {
                                width: 9
                                height: 9
                                radius: 5
                                color: root.onSurface
                            }
                        }
                        Text {
                            visible: root.inputLength === 0
                            text: qsTr("Password")
                            color: "#606873"
                            font.pixelSize: 17
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.authenticateRequested()
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.authState === 1 ? qsTr("Checking…")
                        : root.authState === 3 || root.authState === 4 ? qsTr("Authentication failed")
                        : qsTr("Type your password and press Enter")
                    color: root.authState === 3 || root.authState === 4 ? root.error : "#606873"
                    font.pixelSize: 14
                }
                Item { Layout.fillHeight: true }
            }

            ColumnLayout {
                Layout.preferredWidth: lockContent.width * 0.27
                Layout.fillHeight: true
                spacing: 12

                Text { text: qsTr("SYSTEM"); color: "#5a616c"; font.pixelSize: 12; font.weight: Font.Bold }
                Repeater {
                    model: [
                        [qsTr("CPU"), resources.cpu || "—"],
                        [qsTr("MEMORY"), resources.memory || "—"],
                        [qsTr("UPTIME"), resources.uptime || "—"]
                    ]
                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 66
                        radius: 22
                        color: "#cdd3dc"
                        Column {
                            anchors.fill: parent
                            anchors.margins: 13
                            Text { text: modelData[0]; color: "#626a75"; font.pixelSize: 10; font.weight: Font.Bold }
                            Text { text: modelData[1]; color: root.onSurface; font.pixelSize: 17 }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
                Text {
                    Layout.alignment: Qt.AlignRight
                    text: qsTr("SLEEPY LINUX")
                    color: "#535b66"
                    font.pixelSize: 13
                    font.letterSpacing: 2
                }
            }
        }
    }

    ParallelAnimation {
        id: initialAnimation
        running: true
        NumberAnimation { target: lockContent; property: "opacity"; to: 1; duration: 260; easing.type: Easing.OutCubic }
        NumberAnimation { target: lockContent; property: "scale"; to: 1; duration: 620; easing.type: Easing.OutBack }
        NumberAnimation { target: lockContent; property: "rotation"; to: 0; duration: 620; easing.type: Easing.OutCubic }
        SequentialAnimation {
            PauseAnimation { duration: 250 }
            ParallelAnimation {
                NumberAnimation { target: content; property: "opacity"; to: 1; duration: 260 }
                NumberAnimation { target: content; property: "scale"; to: 1; duration: 360; easing.type: Easing.OutCubic }
            }
        }
    }

    SequentialAnimation {
        id: unlockAnimation
        running: root.authState === 2
        ParallelAnimation {
            NumberAnimation { target: content; property: "opacity"; to: 0; duration: 180 }
            NumberAnimation { target: content; property: "scale"; to: 0.82; duration: 240; easing.type: Easing.InCubic }
        }
        ParallelAnimation {
            NumberAnimation { target: lockContent; property: "scale"; to: 0.12; duration: 320; easing.type: Easing.InBack }
            NumberAnimation { target: lockContent; property: "rotation"; to: 18; duration: 320; easing.type: Easing.InCubic }
            NumberAnimation { target: lockContent; property: "opacity"; to: 0; duration: 300 }
        }
    }
}
