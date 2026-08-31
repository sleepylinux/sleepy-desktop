// SPDX-License-Identifier: GPL-3.0-only
// Strict desktop-v3 daily dashboard presentation for one confirmed output.

pragma ComponentBehavior: Bound

import QtQuick 6.0

Column {
    id: root

    required property var outputState
    required property var colors
    readonly property alias initialFocusItem: dashboardOverviewTab
    spacing: 10

    Row {
        spacing: 6
        CoreOverlayButton {
            id: dashboardOverviewTab
            objectName: "dashboardTab:overview"
            label: "Overview"
            selected: root.outputState.dashboardTab === "overview"
            accent: root.colors.accent || "#8ab4f8"
            foreground: root.colors.textPrimary || "#f1f3f4"
            onTriggered: root.outputState.setDashboardTab("overview")
        }
        Repeater {
            model: [
                {id: "media", label: "Media"},
                {id: "schedule", label: "Schedule"},
                {id: "weather", label: "Weather"},
                {id: "resources", label: "System"}
            ]
            delegate: CoreOverlayButton {
                required property var modelData
                objectName: "dashboardTab:" + modelData.id
                label: modelData.label
                selected: root.outputState.dashboardTab === modelData.id
                accent: root.colors.accent || "#8ab4f8"
                foreground: root.colors.textPrimary || "#f1f3f4"
                onTriggered: root.outputState.setDashboardTab(modelData.id)
            }
        }
    }

    Flickable {
        id: dashboardScroller
        width: parent.width
        height: Math.max(0, root.height - 48)
        clip: true
        contentWidth: width
        contentHeight: dashboardBody.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        Accessible.role: Accessible.Pane
        Accessible.name: "Daily dashboard"

        Column {
            id: dashboardBody
            width: dashboardScroller.width
            spacing: 8

            Column {
                width: parent.width
                spacing: 8
                visible: root.outputState.dashboardTab === "overview"

                Repeater {
                    model: [
                        {label: "Media", available: root.outputState.mediaAvailable,
                            count: root.outputState.players.length,
                            diagnostic: root.outputState.mediaDiagnostic},
                        {label: "Calendar", available: root.outputState.calendarAvailable,
                            count: root.outputState.calendarEvents.length,
                            diagnostic: root.outputState.calendarDiagnostic},
                        {label: "Weather", available: root.outputState.weatherAvailable,
                            count: root.outputState.weatherForecast.length,
                            diagnostic: root.outputState.weatherDiagnostic},
                        {label: "System", available: root.outputState.resourcesAvailable,
                            count: root.outputState.resourceSamples.length,
                            diagnostic: root.outputState.resourcesDiagnostic}
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        width: dashboardBody.width
                        height: 58
                        radius: 14
                        color: "#2a2e33"
                        Accessible.role: Accessible.ListItem
                        Accessible.name: modelData.available
                            ? modelData.label + ", " + modelData.count + " items"
                            : modelData.label + ", " + modelData.diagnostic

                        Row {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10
                            Text {
                                textFormat: Text.PlainText
                                width: parent.width - overviewCount.width - 10
                                text: parent.parent.modelData.label
                                color: root.colors.textPrimary || "#f1f3f4"
                                font.bold: true
                            }
                            Text {
                                textFormat: Text.PlainText
                                id: overviewCount
                                text: parent.parent.modelData.available
                                    ? String(parent.parent.modelData.count)
                                    : parent.parent.modelData.diagnostic
                                color: parent.parent.modelData.available
                                    ? (root.colors.textSecondary || "#bdc1c6") : "#f2b8b5"
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 8
                visible: root.outputState.dashboardTab === "media"

                Text {
                    textFormat: Text.PlainText
                    objectName: "dashboardUnavailable:media"
                    visible: !root.outputState.mediaAvailable
                    width: parent.width
                    text: root.outputState.mediaDiagnostic
                    color: "#f2b8b5"
                    wrapMode: Text.Wrap
                    Accessible.role: Accessible.StaticText
                    Accessible.name: text
                }
                Repeater {
                    model: root.outputState.players
                    delegate: Rectangle {
                        id: playerRow
                        required property var modelData
                        objectName: "dashboardPlayer:" + modelData.id
                        width: dashboardBody.width
                        height: 104
                        radius: 16
                        color: "#2a2e33"
                        Accessible.role: Accessible.ListItem
                        Accessible.name: modelData.identity + ", " + modelData.title

                        Column {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 6
                            Text {
                                textFormat: Text.PlainText
                                objectName: "dashboardPlayerTitle:" + playerRow.modelData.id
                                width: parent.width
                                text: playerRow.modelData.title.length
                                    ? playerRow.modelData.title : playerRow.modelData.identity
                                color: root.colors.textPrimary || "#f1f3f4"
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Text {
                                textFormat: Text.PlainText
                                width: parent.width
                                text: playerRow.modelData.artist
                                color: root.colors.textSecondary || "#bdc1c6"
                                elide: Text.ElideRight
                            }
                            Row {
                                spacing: 6
                                Repeater {
                                    model: [
                                        {id: "previous", label: "Previous"},
                                        {id: "playPause", label: playerRow.modelData.playing
                                            ? "Pause" : "Play"},
                                        {id: "next", label: "Next"}
                                    ]
                                    delegate: CoreOverlayButton {
                                        required property var modelData
                                        objectName: "dashboardMediaTransport:"
                                            + playerRow.modelData.id + ":" + modelData.id
                                        height: 30
                                        label: modelData.label
                                        enabled: root.outputState.mediaAvailable
                                            && !root.outputState.busy
                                        description: enabled ? label
                                            : root.outputState.busy
                                                ? "Another desktop command is pending"
                                                : root.outputState.mediaDiagnostic
                                        onTriggered: root.outputState.controlPlayer(
                                            String(playerRow.modelData.id), modelData.id)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 8
                visible: root.outputState.dashboardTab === "schedule"

                Text {
                    textFormat: Text.PlainText
                    objectName: "dashboardUnavailable:calendar"
                    visible: !root.outputState.calendarAvailable
                    width: parent.width
                    text: root.outputState.calendarDiagnostic
                    color: "#f2b8b5"
                    wrapMode: Text.Wrap
                    Accessible.role: Accessible.StaticText
                    Accessible.name: text
                }
                Repeater {
                    model: root.outputState.calendarEvents
                    delegate: Rectangle {
                        required property var modelData
                        objectName: "dashboardCalendarEvent:" + modelData.id
                        width: dashboardBody.width
                        height: 68
                        radius: 14
                        color: "#2a2e33"
                        Accessible.role: Accessible.ListItem
                        Accessible.name: modelData.summary + ", " + modelData.startsAt
                        Column {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 4
                            Text {
                                textFormat: Text.PlainText
                                objectName: "dashboardCalendarSummary:" + parent.parent.modelData.id
                                width: parent.width
                                text: parent.parent.modelData.summary
                                color: root.colors.textPrimary || "#f1f3f4"
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Text {
                                textFormat: Text.PlainText
                                width: parent.width
                                text: parent.parent.modelData.startsAt
                                color: root.colors.textSecondary || "#bdc1c6"
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 8
                visible: root.outputState.dashboardTab === "weather"

                Text {
                    textFormat: Text.PlainText
                    objectName: "dashboardUnavailable:weather"
                    visible: !root.outputState.weatherAvailable
                    width: parent.width
                    text: root.outputState.weatherDiagnostic
                    color: "#f2b8b5"
                    wrapMode: Text.Wrap
                    Accessible.role: Accessible.StaticText
                    Accessible.name: text
                }
                Repeater {
                    model: root.outputState.weatherForecast
                    delegate: Rectangle {
                        required property var modelData
                        objectName: "dashboardWeather:" + modelData.at
                        width: dashboardBody.width
                        height: 62
                        radius: 14
                        color: "#2a2e33"
                        Accessible.role: Accessible.ListItem
                        Accessible.name: modelData.symbol + ", "
                            + modelData.temperatureC + " degrees Celsius"
                        Row {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10
                            Text {
                                textFormat: Text.PlainText
                                width: parent.width - weatherTemperature.width - 10
                                text: parent.parent.modelData.symbol
                                color: root.colors.textPrimary || "#f1f3f4"
                                font.bold: true
                            }
                            Text {
                                textFormat: Text.PlainText
                                id: weatherTemperature
                                text: Math.round(parent.parent.modelData.temperatureC) + " °C"
                                color: root.colors.textSecondary || "#bdc1c6"
                            }
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 8
                visible: root.outputState.dashboardTab === "resources"

                Text {
                    textFormat: Text.PlainText
                    objectName: "dashboardUnavailable:resources"
                    visible: !root.outputState.resourcesAvailable
                    width: parent.width
                    text: root.outputState.resourcesDiagnostic
                    color: "#f2b8b5"
                    wrapMode: Text.Wrap
                    Accessible.role: Accessible.StaticText
                    Accessible.name: text
                }
                Repeater {
                    model: root.outputState.resourceSamples
                    delegate: Rectangle {
                        required property var modelData
                        objectName: "dashboardResource:" + modelData.id
                        width: dashboardBody.width
                        height: 66
                        radius: 14
                        color: "#2a2e33"
                        Accessible.role: Accessible.ListItem
                        Accessible.name: modelData.id + ", CPU "
                            + Math.round(modelData.cpuUsage * 100) + " percent, memory "
                            + Math.round(modelData.memoryUsage * 100) + " percent"
                        Text {
                            textFormat: Text.PlainText
                            anchors.fill: parent
                            anchors.margins: 12
                            text: parent.modelData.id + "  CPU "
                                + Math.round(parent.modelData.cpuUsage * 100) + "%  Memory "
                                + Math.round(parent.modelData.memoryUsage * 100) + "%  Load "
                                + Number(parent.modelData.loadOne).toFixed(1)
                            color: root.colors.textPrimary || "#f1f3f4"
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
