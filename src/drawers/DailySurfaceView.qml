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
    focusTargets: ({"search": search, "notifications": list, "workspaces": list,
                    "calendar": list, "themes": list})

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Home) { if (list.count) list.currentIndex = 0; event.accepted = true; }
        else if (event.key === Qt.Key_End) { if (list.count) list.currentIndex = list.count - 1; event.accepted = true; }
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
                required property var modelData
                required property int index
                width: ListView.view.width; height: 64
                activeFocusOnTab: true
                Accessible.role: Accessible.ListItem
                Accessible.name: String(modelData.name || modelData.summary
                                        || modelData.title || modelData.id || "Item")
                function activate() { return root.dailyState.activateItem(root.surfaceId, modelData); }
                Keys.onReturnPressed: event => { activate(); event.accepted = true; }
                Keys.onEnterPressed: event => { activate(); event.accepted = true; }
                Keys.onSpacePressed: event => { activate(); event.accepted = true; }
                Keys.onDeletePressed: event => {
                    if (root.surfaceId === "overview") {
                        root.dailyState.closeOverviewItem(modelData); event.accepted = true;
                    }
                }
                Rectangle {
                    anchors.fill: parent; anchors.margins: 3; radius: 10
                    color: parent.activeFocus ? root.colors.accentSoft : root.colors.surfaceRaised
                }
                Text {
                    anchors.fill: parent; anchors.margins: 12
                    textFormat: Text.PlainText
                    text: String(parent.modelData.name || parent.modelData.summary
                                 || parent.modelData.title || parent.modelData.id || "Item")
                    color: root.colors.textPrimary; elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
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
