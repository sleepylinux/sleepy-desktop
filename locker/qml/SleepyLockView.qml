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

    // Immutable native-locker roles follow the shared Sleepy dark palette.
    // No desktop state or mutable configuration is imported into the lock surface.
    readonly property bool hasWeather: weather.temperature !== undefined && weather.temperature !== null && weather.temperature !== ""
    readonly property bool hasMedia: Boolean(media.title)
    readonly property bool hasNotifications: Boolean(notificationSummary.text)
    readonly property bool hasDetails: hasWeather || hasMedia || hasNotifications
    readonly property var resourceRows: [
        [qsTr("CPU"), resources.cpu],
        [qsTr("MEMORY"), resources.memory],
        [qsTr("UPTIME"), resources.uptime]
    ].filter(row => row[1] !== undefined && row[1] !== null && row[1] !== "")

    readonly property color surface: "#181620"
    readonly property color surfaceText: "#e8e2f0"
    readonly property color surfaceContainer: "#2b2438"
    readonly property color secondaryContainer: "#3a3152"
    readonly property color mutedText: "#d0c7dc"
    readonly property color accent: "#b9a7ff"
    readonly property color outline: "#3b3249"
    readonly property color errorContainer: "#482330"
    readonly property color error: "#ef9aaf"

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.clockText = Qt.formatTime(new Date(), "hh:mm")
    }

    Rectangle {
        anchors.fill: parent
        color: "#100c18"

        gradient: Gradient {
            GradientStop { position: 0; color: "#211c2b" }
            GradientStop { position: 0.52; color: "#181620" }
            GradientStop { position: 1; color: "#2b2438" }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#65000000"
    }

    Item {
        id: lockContent
        anchors.centerIn: parent
        width: Math.min(root.width - 48, root.hasDetails || root.resourceRows.length ? root.height * 0.8 * 1.62 : 620)
        height: Math.min(root.height - 48, root.height * 0.8)
        scale: 0.15
        rotation: -18
        opacity: 0

        Rectangle {
            anchors.fill: parent
            radius: 42
            color: root.surface
            border.width: 1
            border.color: root.outline
        }

        GridLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 28
            columns: 1 + (root.hasDetails ? 1 : 0) + (root.resourceRows.length ? 1 : 0)
            columnSpacing: 24
            opacity: 0
            scale: 0.92

            ColumnLayout {
                objectName: "detailsPanel"
                visible: root.hasDetails
                Layout.preferredWidth: lockContent.width * 0.27
                Layout.fillHeight: true
                spacing: 14

                Text {
                    visible: root.hasWeather
                    text: root.hasWeather ? String(root.weather.temperature) : ""
                    color: root.surfaceText
                    font.pixelSize: 46
                    font.weight: Font.DemiBold
                }
                Text {
                    visible: root.hasWeather && Boolean(root.weather.description)
                    text: root.weather.description || ""
                    color: root.mutedText
                    font.pixelSize: 17
                }
                Rectangle {
                    Layout.fillWidth: true
                    visible: root.hasMedia
                    Layout.preferredHeight: 118
                    radius: 25
                    color: root.secondaryContainer

                    Column {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 7
                        Text { text: qsTr("NOW PLAYING"); color: root.mutedText; font.pixelSize: 11; font.weight: Font.Bold }
                        Text { width: parent.width; elide: Text.ElideRight; text: root.media.title || ""; color: root.surfaceText; font.pixelSize: 18 }
                        Text { width: parent.width; elide: Text.ElideRight; text: root.media.artist || ""; color: root.mutedText; font.pixelSize: 14 }
                    }
                }
                Item { Layout.fillHeight: true }
                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    visible: root.hasNotifications
                    text: root.notificationSummary.text || ""
                    color: root.mutedText
                    font.pixelSize: 14
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 14

                Item { Layout.fillHeight: true }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.clockText
                    color: root.surfaceText
                    font.pixelSize: Math.max(72, lockContent.height * 0.15)
                    font.weight: Font.Light
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDate(new Date(), "dddd  •  d MMM").toUpperCase()
                    color: root.mutedText
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
                        color: root.accent
                        font.pixelSize: 62
                    }
                }
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 18
                    width: Math.min(360, lockContent.width * (root.hasDetails || root.resourceRows.length ? 0.38 : 0.8))
                    height: 58
                    radius: 29
                    color: root.authState === 3 || root.authState === 4 ? root.errorContainer : root.surfaceContainer
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
                                color: root.surfaceText
                            }
                        }
                        Text {
                            visible: root.inputLength === 0
                            text: qsTr("Password")
                            color: root.mutedText
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
                    color: root.authState === 3 || root.authState === 4 ? root.error : root.mutedText
                    font.pixelSize: 14
                }
                Item { Layout.fillHeight: true }
            }

            ColumnLayout {
                objectName: "resourcesPanel"
                visible: root.resourceRows.length > 0
                Layout.preferredWidth: lockContent.width * 0.27
                Layout.fillHeight: true
                spacing: 12

                Text { text: qsTr("SYSTEM"); color: root.mutedText; font.pixelSize: 12; font.weight: Font.Bold }
                Repeater {
                    model: root.resourceRows
                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 66
                        radius: 22
                        color: "#2b2438"
                        Column {
                            anchors.fill: parent
                            anchors.margins: 13
                            Text { text: modelData[0]; color: root.mutedText; font.pixelSize: 10; font.weight: Font.Bold }
                            Text { text: modelData[1]; color: root.surfaceText; font.pixelSize: 17 }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
                Text {
                    Layout.alignment: Qt.AlignRight
                    text: qsTr("SLEEPY LINUX")
                    color: root.mutedText
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
