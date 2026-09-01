// SPDX-License-Identifier: GPL-3.0-only
// Sleepy rewrite of upstream v2.4.0 window info for daemon-owned compositor state.

pragma ComponentBehavior: Bound

import QtQuick 6.0

Column {
    id: root
    objectName: "task10WindowInfo"

    required property var outputState
    required property var colors
    readonly property var windowRows: {
        void(root.outputState.windows);
        void(root.outputState.workspaceRows);
        const workspaceIds = root.outputState.workspaceRows.map(row => String(row.id));
        return root.outputState.windows.filter(
            window => workspaceIds.indexOf(String(window.workspaceId)) >= 0);
    }
    readonly property bool blocked: Boolean(root.outputState.busy)
    spacing: 8

    function contains(windowId) {
        return root.windowRows.some(window => String(window.id) === String(windowId));
    }
    function requestFocus(windowId) {
        return !root.blocked && root.outputState.compositorActions.focusWindow
            && root.contains(windowId) && root.outputState.focusWindow(String(windowId));
    }
    function requestClose(windowId) {
        return !root.blocked && root.outputState.compositorActions.closeWindow
            && root.contains(windowId) && root.outputState.closeWindow(String(windowId));
    }
    function requestFullscreen(windowId) {
        return !root.blocked && root.outputState.compositorActions.toggleFullscreen
            && root.contains(windowId) && root.outputState.toggleWindowFullscreen(String(windowId));
    }
    function requestFloating(windowId) {
        return !root.blocked && root.outputState.compositorActions.toggleFloating
            && root.contains(windowId) && root.outputState.toggleWindowFloating(String(windowId));
    }
    function requestPinned(windowId) {
        return !root.blocked && root.outputState.compositorActions.togglePinned
            && root.contains(windowId) && root.outputState.toggleWindowPinned(String(windowId));
    }
    function requestGroup(windowId) {
        return !root.blocked && root.outputState.compositorActions.toggleGroup
            && root.contains(windowId) && root.outputState.toggleWindowGroup(String(windowId));
    }

    Text {
        text: "Windows"
        textFormat: Text.PlainText
        color: root.colors.textPrimary || "#f1f3f4"
        font.bold: true
        Accessible.role: Accessible.Heading
        Accessible.name: text
    }

    Text {
        visible: root.windowRows.length === 0
        text: "No windows on this output"
        textFormat: Text.PlainText
        color: root.colors.textSecondary || "#bdc1c6"
        Accessible.role: Accessible.StaticText
        Accessible.name: text
    }

    Repeater {
        model: root.windowRows
        delegate: Rectangle {
            id: row
            required property var modelData
            objectName: "windowInfo:" + modelData.id
            width: 320
            height: 94
            radius: 14
            color: root.colors.surface || "#2a2e33"
            Accessible.role: Accessible.ListItem
            Accessible.name: modelData.title + ", " + modelData.applicationId

            Column {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 5
                Text {
                    width: parent.width
                    text: row.modelData.title || row.modelData.applicationId
                    textFormat: Text.PlainText
                    color: root.colors.textPrimary || "#f1f3f4"
                    font.bold: row.modelData.focused
                    elide: Text.ElideRight
                }
                Row {
                    spacing: 5
                    WindowAction {
                        actionId: "focus"
                        windowId: String(row.modelData.id)
                        label: "Focus"
                        available: Boolean(root.outputState.compositorActions.focusWindow)
                        onTriggered: root.requestFocus(row.modelData.id)
                    }
                    WindowAction {
                        actionId: "fullscreen"
                        windowId: String(row.modelData.id)
                        label: row.modelData.fullscreen ? "Window" : "Full"
                        available: Boolean(root.outputState.compositorActions.toggleFullscreen)
                        onTriggered: root.requestFullscreen(row.modelData.id)
                    }
                    WindowAction {
                        actionId: "floating"
                        windowId: String(row.modelData.id)
                        label: row.modelData.floating ? "Tile" : "Float"
                        available: Boolean(root.outputState.compositorActions.toggleFloating)
                        onTriggered: root.requestFloating(row.modelData.id)
                    }
                    WindowAction {
                        actionId: "close"
                        windowId: String(row.modelData.id)
                        label: "Close"
                        available: Boolean(root.outputState.compositorActions.closeWindow)
                        onTriggered: root.requestClose(row.modelData.id)
                    }
                }
            }
        }
    }

    component WindowAction: Rectangle {
        id: button
        required property string actionId
        required property string windowId
        required property string label
        property bool available: false
        signal triggered
        objectName: "windowAction:" + windowId + ":" + actionId
        width: 60
        height: 30
        radius: 10
        enabled: available && !root.blocked
        activeFocusOnTab: enabled
        color: root.colors.accent || "#8ab4f8"
        Accessible.role: Accessible.Button
        Accessible.name: label
        Accessible.ignored: !enabled
        Keys.onReturnPressed: triggered()
        Keys.onSpacePressed: triggered()
        Accessible.onPressAction: { if (enabled) triggered(); }
        Text {
            anchors.centerIn: parent
            text: button.label
            textFormat: Text.PlainText
            color: "#101418"
            font.pixelSize: 11
        }
        TapHandler { enabled: button.enabled; onTapped: button.triggered() }
    }
}
