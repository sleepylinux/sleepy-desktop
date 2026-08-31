// SPDX-License-Identifier: GPL-3.0-only
// Derived from Caelestia v2.4.0 right-side launcher/notification drawer geometry.

pragma ComponentBehavior: Bound

import QtQuick 6.0

FocusScope {
    id: root
    objectName: "coreOverlayView"

    required property var outputState
    readonly property var colors: root.outputState.colors
    readonly property Item initialFocusItem: root.outputState.activeOverlay === "launcher"
        ? launcherSearch : root.outputState.activeOverlay === "dashboard"
            ? dashboardContent.initialFocusItem : dndButton.enabled ? dndButton : closeButton
    readonly property string focusRequestKey: root.outputState.overlayOpen
        ? root.outputState.activeOverlay + ":" + root.initialFocusItem.objectName
        : ""

    clip: true
    visible: root.outputState.overlayPresentationVisible
    Keys.onEscapePressed: event => {
        root.outputState.closeOverlay();
        event.accepted = true;
    }

    function focusInitialControl() {
        if (!root.outputState.overlayOpen)
            return;
        Qt.callLater(function() {
            const target = root.initialFocusItem;
            if (root.outputState.overlayOpen && target && target.enabled)
                target.forceActiveFocus();
        });
    }

    onVisibleChanged: {
        if (visible)
            root.focusInitialControl();
    }
    onFocusRequestKeyChanged: root.focusInitialControl()

    Column {
        id: toastColumn
        objectName: "notificationToasts"
        visible: !panel.visible && root.outputState.toastItems.length > 0
        anchors {
            top: parent.top
            right: parent.right
            margins: 18
        }
        width: 340
        spacing: 8

        Repeater {
            model: root.outputState.toastItems.slice(0, 3)
            delegate: Rectangle {
                required property var modelData
                objectName: "notificationToast:" + modelData.id
                width: toastColumn.width
                height: 72
                radius: 18
                color: root.colors.surface || "#202124"
                border.width: 1
                border.color: root.colors.accent || "#8ab4f8"
                Accessible.role: Accessible.Notification
                Accessible.name: modelData.summary

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4
                    Text {
                        width: parent.width
                        text: modelData.summary
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: root.colors.textPrimary || "#f1f3f4"
                        font.pixelSize: 13
                        font.bold: true
                    }
                    Text {
                        width: parent.width
                        text: modelData.body
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: root.colors.textSecondary || "#bdc1c6"
                        font.pixelSize: 11
                    }
                }
            }
        }
    }

    Rectangle {
        id: panel
        objectName: "coreOverlayPanel"
        visible: root.outputState.overlayOpen
        anchors {
            top: parent.top
            right: parent.right
            bottom: parent.bottom
            margins: 14
        }
        width: Math.min(540, Math.max(420, parent.width - 28))
        radius: 26
        color: root.colors.surface || "#202124"
        border.width: 1
        border.color: root.colors.accent || "#8ab4f8"
        opacity: visible ? 1 : 0
        scale: visible ? 1 : 0.98

        Behavior on opacity {
            NumberAnimation {
                duration: root.outputState.motionDuration
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: root.outputState.motionDuration
                easing.type: Easing.OutCubic
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            Row {
                width: parent.width
                spacing: 10
                Text {
                    width: parent.width - closeButton.width - 10
                    height: closeButton.height
                    verticalAlignment: Text.AlignVCenter
                    text: root.outputState.activeOverlay === "launcher"
                        ? "Applications" : root.outputState.activeOverlay === "dashboard"
                            ? "Today" : "Notifications"
                    color: root.colors.textPrimary || "#f1f3f4"
                    font.pixelSize: 22
                    font.bold: true
                }
                CoreOverlayButton {
                    id: closeButton
                    objectName: "overlayClose"
                    width: 42
                    label: "Close"
                    accent: root.colors.accent || "#8ab4f8"
                    foreground: root.colors.textPrimary || "#f1f3f4"
                    onTriggered: root.outputState.closeOverlay()
                }
            }

            CoreDashboardView {
                id: dashboardContent
                width: parent.width
                height: Math.max(0, panel.height - 90)
                visible: root.outputState.activeOverlay === "dashboard"
                outputState: root.outputState
                colors: root.colors
            }

            Column {
                id: launcherContent
                width: parent.width
                spacing: 10
                visible: root.outputState.activeOverlay === "launcher"

                Row {
                    spacing: 8
                    CoreOverlayButton {
                        label: "Apps"
                        selected: true
                        accent: root.colors.accent || "#8ab4f8"
                        foreground: root.colors.textPrimary || "#f1f3f4"
                    }
                    CoreOverlayButton {
                        objectName: "launcherMode:calculator"
                        label: "Calculator"
                        enabled: root.outputState.launcherCalculatorSupported
                        description: "Calculator mode is not provided by desktop protocol v3"
                    }
                    CoreOverlayButton {
                        objectName: "launcherMode:command"
                        label: "Commands"
                        enabled: root.outputState.launcherCommandModeSupported
                        description: "Command mode is unavailable; local process execution is disabled"
                    }
                    CoreOverlayButton {
                        objectName: "launcherMode:actions"
                        label: "App actions"
                        enabled: root.outputState.launcherActionsSupported
                        description: "App actions are unavailable until daemon-issued action IDs are provided"
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 44
                    radius: 13
                    color: "#2a2e33"
                    border.width: launcherSearch.activeFocus ? 2 : 1
                    border.color: launcherSearch.activeFocus
                        ? (root.colors.accent || "#8ab4f8") : "#4a4f54"

                    TextInput {
                        id: launcherSearch
                        objectName: "launcherSearch"
                        anchors.fill: parent
                        anchors.margins: 11
                        text: root.outputState.launcherSearchText
                        color: root.colors.textPrimary || "#f1f3f4"
                        font.pixelSize: 14
                        activeFocusOnTab: visible
                        Accessible.role: Accessible.EditableText
                        Accessible.name: "Search installed applications"
                        onTextEdited: root.outputState.launcherSearchText = text
                        Keys.onEscapePressed: event => {
                            root.outputState.closeOverlay();
                            event.accepted = true;
                        }
                    }
                }

                Text {
                    visible: !root.outputState.launcherAvailable
                    width: parent.width
                    text: root.outputState.launcherDiagnostic
                    color: "#f2b8b5"
                    wrapMode: Text.Wrap
                    Accessible.role: Accessible.StaticText
                    Accessible.name: text
                }

                ListView {
                    id: launcherList
                    objectName: "launcherList"
                    width: parent.width
                    height: Math.max(0, panel.height - 190)
                    clip: true
                    spacing: 7
                    model: root.outputState.filteredLauncherEntries
                    activeFocusOnTab: visible && count > 0
                    Accessible.role: Accessible.List
                    Accessible.name: "Installed applications"
                    delegate: CoreOverlayButton {
                        required property var modelData
                        objectName: "launcherEntry:" + modelData.id
                        width: launcherList.width
                        label: modelData.name
                        description: enabled ? "Launch " + modelData.name
                            : root.outputState.busy ? "Another desktop command is pending"
                            : root.outputState.launcherDiagnostic
                        enabled: root.outputState.launcherAvailable && !root.outputState.busy
                        accent: root.colors.accent || "#8ab4f8"
                        foreground: root.colors.textPrimary || "#f1f3f4"
                        onTriggered: root.outputState.launchEntry(String(modelData.id))
                    }
                }
            }

            Column {
                id: notificationContent
                width: parent.width
                spacing: 10
                visible: root.outputState.activeOverlay === "notifications"

                CoreOverlayButton {
                    id: dndButton
                    objectName: "notificationDnd"
                    label: root.outputState.dndEnabled ? "Do not disturb: on" : "Do not disturb: off"
                    selected: root.outputState.dndEnabled
                    enabled: root.outputState.notificationsAvailable && !root.outputState.busy
                    description: enabled ? "Toggle do not disturb"
                        : root.outputState.busy ? "Another desktop command is pending"
                        : root.outputState.notificationsDiagnostic
                    accent: root.colors.accent || "#8ab4f8"
                    foreground: root.colors.textPrimary || "#f1f3f4"
                    onTriggered: root.outputState.setDnd(!root.outputState.dndEnabled)
                }

                Text {
                    visible: !root.outputState.notificationsAvailable
                    width: parent.width
                    text: root.outputState.notificationsDiagnostic
                    color: "#f2b8b5"
                    wrapMode: Text.Wrap
                    Accessible.role: Accessible.StaticText
                    Accessible.name: text
                }

                ListView {
                    id: notificationList
                    objectName: "notificationList"
                    width: parent.width
                    height: Math.max(0, panel.height - 130)
                    clip: true
                    spacing: 8
                    model: root.outputState.notificationItems
                    activeFocusOnTab: visible && count > 0
                    Accessible.role: Accessible.List
                    Accessible.name: "Notification history"

                    delegate: Rectangle {
                        id: notificationRow
                        required property var modelData
                        width: notificationList.width
                        height: 106
                        radius: 16
                        color: "#2a2e33"
                        Accessible.role: Accessible.ListItem
                        Accessible.name: modelData.summary

                        Column {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 6
                            Text {
                                width: parent.width
                                text: notificationRow.modelData.summary
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                color: root.colors.textPrimary || "#f1f3f4"
                                font.bold: true
                            }
                            Text {
                                width: parent.width
                                text: notificationRow.modelData.body
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                color: root.colors.textSecondary || "#bdc1c6"
                            }
                            Row {
                                spacing: 6
                                Repeater {
                                    model: notificationRow.modelData.actions || []
                                    delegate: CoreOverlayButton {
                                        required property var modelData
                                        objectName: "notificationAction:"
                                            + notificationRow.modelData.id + ":" + modelData.id
                                        height: 30
                                        label: modelData.label
                                        enabled: root.outputState.notificationsAvailable
                                            && modelData.state === "available"
                                            && !root.outputState.busy
                                        description: enabled ? label
                                            : root.outputState.busy
                                                ? "Another desktop command is pending"
                                                : label + ", expired or unavailable"
                                        onTriggered: root.outputState.invokeNotificationAction(
                                            Number(notificationRow.modelData.id), String(modelData.id))
                                    }
                                }
                                CoreOverlayButton {
                                    objectName: "notificationArchive:" + notificationRow.modelData.id
                                    height: 30
                                    label: "Archive"
                                    enabled: root.outputState.notificationsAvailable
                                        && !notificationRow.modelData.archived
                                        && !root.outputState.busy
                                    description: enabled ? "Archive notification"
                                        : root.outputState.busy
                                            ? "Another desktop command is pending"
                                            : "Archive unavailable"
                                    onTriggered: root.outputState.archiveNotification(
                                        Number(notificationRow.modelData.id))
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
