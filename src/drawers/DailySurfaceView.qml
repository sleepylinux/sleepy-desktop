// SPDX-License-Identifier: GPL-3.0-only

pragma ComponentBehavior: Bound

import QtQuick 6.0
import "../surfaces" as Surfaces

Surfaces.DrawerFrame {
    id: root
    required property var dailyState
    required property var iconRegistry
    readonly property string surfaceId: descriptor.id
    readonly property string viewState: dailyState.stateFor(surfaceId)
    readonly property var rows: dailyState.itemsFor(surfaceId)
    readonly property alias listView: list
    readonly property alias searchField: search
    function displayLabel(item) {
        if (!item || typeof item !== "object") return "Item";
        return String(item.summary || item.displayName || item.name
            || item.title || item.id || "Item");
    }
    focusTargets: ({"search": search, "notifications": list, "workspaces": list,
                    "calendar": list, "themes": list})

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Home) { if (list.count) list.currentIndex = 0; event.accepted = true; }
        else if (event.key === Qt.Key_End) { if (list.count) list.currentIndex = list.count - 1; event.accepted = true; }
    }
    function refreshSurface() {
        if (root.surfaceId === "notifications" && root.dailyState.notifications)
            return root.dailyState.notifications.refresh();
        if (root.surfaceId === "widgets") {
            const start = new Date(); const end = new Date(start.getTime() + 14 * 24 * 60 * 60 * 1000);
            return root.dailyState.loadCalendar(start.toISOString(), end.toISOString());
        }
        if (root.surfaceId === "launcher") return root.dailyState.searchLauncher(search.text);
        return false;
    }
    Connections {
        target: root.surfaceController
        function onSurfaceOpened(id, key) {
            if (id === root.surfaceId && key === root.screenKey
                    && (id === "widgets" || id === "notifications")) root.refreshSurface();
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        Surfaces.DrawerHeader {
            width: parent.width
            title: root.descriptor.triggerLabel
            subtitle: root.viewState === "ready" ? "Updated by sleepy-sessiond" : root.viewState
            surfaceId: root.surfaceId
            screenKey: root.screenKey
            surfaceController: root.surfaceController
            tokens: root.tokens
            colors: root.colors
        }

        Row {
            visible: root.surfaceId === "notifications" || root.surfaceId === "widgets"
            spacing: 8
            Rectangle {
                objectName: "dailyRefreshButton"
                width: 92; height: 34; radius: 10; color: root.colors.surfaceRaised
                activeFocusOnTab: visible
                Accessible.role: Accessible.Button; Accessible.name: "Refresh " + root.descriptor.triggerLabel
                Text { anchors.centerIn: parent; text: "Refresh"; color: root.colors.textPrimary }
                Keys.onReturnPressed: event => { root.refreshSurface(); event.accepted = true; }
                Keys.onEnterPressed: event => { root.refreshSurface(); event.accepted = true; }
                Keys.onSpacePressed: event => { root.refreshSurface(); event.accepted = true; }
                MouseArea { anchors.fill: parent; onClicked: root.refreshSurface() }
            }
            Rectangle {
                objectName: "dailyDndButton"
                visible: root.surfaceId === "notifications" && root.dailyState.notifications !== null
                width: 110; height: 34; radius: 10; color: root.colors.surfaceRaised
                activeFocusOnTab: visible
                Accessible.role: Accessible.CheckBox
                Accessible.name: "Do not disturb"
                Accessible.checked: root.dailyState.notifications ? root.dailyState.notifications.dnd : false
                Text { anchors.centerIn: parent; text: root.dailyState.notifications && root.dailyState.notifications.dnd ? "DND on" : "DND off"; color: root.colors.textPrimary }
                function toggleDnd() { root.dailyState.notifications.setDnd(!root.dailyState.notifications.dnd); }
                Keys.onReturnPressed: event => { toggleDnd(); event.accepted = true; }
                Keys.onEnterPressed: event => { toggleDnd(); event.accepted = true; }
                Keys.onSpacePressed: event => { toggleDnd(); event.accepted = true; }
                MouseArea { anchors.fill: parent; onClicked: parent.toggleDnd() }
            }
        }

        Rectangle {
            visible: root.surfaceId === "launcher" || root.surfaceId === "widgets"
            width: parent.width; height: 42; radius: 12
            color: root.colors.surfaceRaised
            border.color: search.activeFocus ? root.colors.accent : root.colors.border
            TextInput {
                id: search
                objectName: "dailySearch"
                anchors.fill: parent; anchors.margins: 10
                color: root.colors.textPrimary
                activeFocusOnTab: visible
                Accessible.role: Accessible.EditableText
                Accessible.name: root.surfaceId === "launcher"
                    ? "Search installed applications" : "Submit a weather location"
                onAccepted: {
                    if (root.surfaceId === "launcher") root.dailyState.searchLauncher(text);
                    else root.dailyState.submitGeocode(text);
                }
                Keys.onEscapePressed: event => {
                    root.surfaceController.close(root.surfaceId, root.screenKey); event.accepted = true;
                }
            }
        }

        Text {
            visible: root.viewState !== "ready"
            width: parent.width
            text: root.viewState === "loading" ? "Loading…"
                : root.viewState === "offline" ? "Service offline"
                : root.viewState === "stale" ? "Showing cached data"
                : root.viewState === "empty" ? "Nothing here yet"
                : root.dailyState.daily.errorString || "Service error"
            color: root.viewState === "error" ? root.colors.error : root.colors.textSecondary
            wrapMode: Text.Wrap
            Accessible.role: Accessible.StaticText
            Accessible.name: text
        }

        ListView {
            id: list
            objectName: "dailyList"
            width: parent.width
            height: Math.max(0, parent.height - y)
            model: root.rows
            clip: true
            activeFocusOnTab: visible && count > 0
            currentIndex: count ? 0 : -1
            keyNavigationWraps: false
            Accessible.role: Accessible.List
            Accessible.name: root.descriptor.triggerLabel + " list"
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Home) { if (count) currentIndex = 0; event.accepted = true; }
                else if (event.key === Qt.Key_End) { if (count) currentIndex = count - 1; event.accepted = true; }
            }
            Keys.onEscapePressed: event => {
                root.surfaceController.close(root.surfaceId, root.screenKey); event.accepted = true;
            }
            delegate: FocusScope {
                id: notificationDelegate
                required property var modelData
                required property int index
                readonly property alias actionRepeater: notificationActions
                width: ListView.view.width; height: 64
                activeFocusOnTab: true
                Accessible.role: Accessible.ListItem
                Accessible.name: root.displayLabel(modelData)
                function activate() {
                    if (root.surfaceId === "notifications" && root.dailyState.notifications) {
                        return root.dailyState.notifications.markRead(modelData.id);
                    }
                    return root.dailyState.activateItem(root.surfaceId, modelData);
                }
                Keys.onReturnPressed: event => { activate(); event.accepted = true; }
                Keys.onEnterPressed: event => { activate(); event.accepted = true; }
                Keys.onSpacePressed: event => { activate(); event.accepted = true; }
                Keys.onDeletePressed: event => {
                    if (root.surfaceId === "overview") {
                        root.dailyState.closeOverviewItem(modelData); event.accepted = true;
                    } else if (root.surfaceId === "notifications" && root.dailyState.notifications) {
                        root.dailyState.notifications.dismiss(modelData.id); event.accepted = true;
                    }
                }
                Rectangle {
                    anchors.fill: parent; anchors.margins: 3; radius: 10
                    color: parent.activeFocus ? root.colors.accentSoft : root.colors.surfaceRaised
                }
                Text {
                    anchors.fill: parent; anchors.margins: 12
                    anchors.rightMargin: actionRow.visible ? actionRow.width + 16 : 12
                    textFormat: Text.PlainText
                    text: root.displayLabel(parent.modelData)
                    color: root.colors.textPrimary; elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    verticalAlignment: Text.AlignVCenter
                }
                Row {
                    id: actionRow
                    property var notification: notificationDelegate.modelData
                    z: 2
                    visible: root.surfaceId === "notifications"
                    anchors.right: parent.right; anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Repeater {
                        id: notificationActions
                        model: actionRow.notification && actionRow.notification.actions
                            ? actionRow.notification.actions : []
                        delegate: Rectangle {
                            required property var modelData
                            width: Math.max(58, actionLabel.implicitWidth + 18); height: 32; radius: 9
                            color: activeFocus ? root.colors.accentSoft : root.colors.surfaceQuiet
                            activeFocusOnTab: true
                            objectName: "notificationAction-" + modelData.id
                            Accessible.role: Accessible.Button
                            Accessible.name: modelData.label
                            Accessible.description: modelData.state === "expired" ? "Action expired" : ""
                            function invoke() {
                                if (modelData.state === "available")
                                    root.dailyState.notifications.invokeAction(actionRow.notification.id, modelData.id);
                            }
                            Keys.onReturnPressed: event => { invoke(); event.accepted = true; }
                            Keys.onEnterPressed: event => { invoke(); event.accepted = true; }
                            Keys.onSpacePressed: event => { invoke(); event.accepted = true; }
                            Text { id: actionLabel; anchors.centerIn: parent; textFormat: Text.PlainText; text: parent.modelData.label; color: root.colors.textPrimary }
                            MouseArea { anchors.fill: parent; onClicked: parent.invoke() }
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: parent.activate()
                }
            }
        }
    }
}
