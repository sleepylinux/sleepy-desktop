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

    function windowById(windowId) {
        return root.windowRows.find(
            window => String(window.id) === String(windowId)) || null;
    }

    function contains(windowId) {
        return root.windowById(windowId) !== null;
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

    function requestMove(windowId, workspaceId) {
        const window = root.windowById(windowId);
        return !root.blocked && root.outputState.compositorActions.moveWindowToWorkspace
            && window !== null
            && String(window.workspaceId) !== String(workspaceId)
            && root.outputState.workspaceRows.some(
                workspace => String(workspace.id) === String(workspaceId))
            && root.outputState.moveWindowToWorkspace(
                String(windowId), String(workspaceId));
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
            height: content.implicitHeight + 16
            radius: 14
            color: root.colors.surface || "#2a2e33"
            Accessible.role: Accessible.ListItem
            Accessible.name: modelData.title + ", " + modelData.applicationId

            Column {
                id: content
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 8
                }
                spacing: 5

                Text {
                    width: parent.width
                    text: row.modelData.title || row.modelData.applicationId
                    textFormat: Text.PlainText
                    color: root.colors.textPrimary || "#f1f3f4"
                    font.bold: row.modelData.focused
                    elide: Text.ElideRight
                }

                Text {
                    objectName: "windowDetails:" + row.modelData.id
                    width: parent.width
                    text: String(row.modelData.applicationId) + " · workspace "
                        + String(row.modelData.workspaceId) + " · "
                        + (row.modelData.focused ? "focused" : "not focused") + " · "
                        + (row.modelData.floating ? "floating" : "tiled") + " · "
                        + (row.modelData.pinned ? "pinned" : "not pinned") + " · "
                        + (row.modelData.grouped ? "grouped" : "not grouped")
                    textFormat: Text.PlainText
                    color: root.colors.textSecondary || "#bdc1c6"
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    Accessible.role: Accessible.StaticText
                    Accessible.name: text
                }

                Text {
                    objectName: "windowPreviewUnavailable:" + row.modelData.id
                    width: parent.width
                    text: "Preview unavailable: desktop protocol v3 provides no safe preview handle"
                    textFormat: Text.PlainText
                    color: root.colors.textSecondary || "#bdc1c6"
                    font.pixelSize: 9
                    elide: Text.ElideRight
                    Accessible.role: Accessible.StaticText
                    Accessible.name: text
                }

                Flow {
                    width: parent.width
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
                        actionId: "pinned"
                        windowId: String(row.modelData.id)
                        label: row.modelData.pinned ? "Unpin" : "Pin"
                        available: Boolean(root.outputState.compositorActions.togglePinned)
                        onTriggered: root.requestPinned(row.modelData.id)
                    }
                    WindowAction {
                        actionId: "group"
                        windowId: String(row.modelData.id)
                        label: row.modelData.grouped ? "Ungroup" : "Group"
                        available: Boolean(root.outputState.compositorActions.toggleGroup)
                        onTriggered: root.requestGroup(row.modelData.id)
                    }
                    WindowAction {
                        actionId: "close"
                        windowId: String(row.modelData.id)
                        label: "Close"
                        available: Boolean(root.outputState.compositorActions.closeWindow)
                        onTriggered: root.requestClose(row.modelData.id)
                    }
                }

                Text {
                    text: "Move to workspace"
                    textFormat: Text.PlainText
                    color: root.colors.textSecondary || "#bdc1c6"
                    font.pixelSize: 10
                    Accessible.role: Accessible.Heading
                    Accessible.name: text
                }

                Flow {
                    width: parent.width
                    spacing: 5
                    Repeater {
                        model: root.outputState.workspaceRows
                        delegate: WorkspaceAction {
                            required property var modelData
                            windowId: String(row.modelData.id)
                            workspaceId: String(modelData.id)
                            label: String(modelData.name || modelData.id)
                            current: String(row.modelData.workspaceId) === String(modelData.id)
                            available: Boolean(
                                root.outputState.compositorActions.moveWindowToWorkspace)
                            onTriggered: root.requestMove(row.modelData.id, modelData.id)
                        }
                    }
                }
            }
        }
    }

    component ActionFeedback: Text {
        required property string actionKey
        readonly property var feedback:
            (root.outputState.actionFeedback || ({}))[actionKey] || ({})
        readonly property string actionStatus:
            feedback.status || root.outputState.actionStatus(actionKey)
        objectName: "commandDiagnostic:" + actionKey
        visible: ["pending", "rejected", "timeout"].indexOf(actionStatus) >= 0
        text: feedback.diagnostic || root.outputState.actionDiagnostic(actionKey)
        textFormat: Text.PlainText
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        color: actionStatus === "pending"
            ? (root.colors.textSecondary || "#bdc1c6") : "#f2b8b5"
        font.pixelSize: 8
        Accessible.role: Accessible.StaticText
        Accessible.name: text
    }

    component WindowAction: Rectangle {
        id: button
        required property string actionId
        required property string windowId
        required property string label
        property bool available: false
        readonly property string actionKey: "window:" + windowId + ":" + actionId
        signal triggered
        objectName: "windowAction:" + windowId + ":" + actionId
        width: 60
        height: 42
        radius: 10
        enabled: available && !root.blocked
        activeFocusOnTab: enabled
        color: root.colors.accent || "#8ab4f8"
        Accessible.role: Accessible.Button
        Accessible.name: label
        Accessible.description: feedback.text.length ? feedback.text : label
        Accessible.ignored: !enabled
        Keys.onReturnPressed: triggered()
        Keys.onSpacePressed: triggered()
        Accessible.onPressAction: { if (enabled) triggered(); }

        Column {
            anchors.centerIn: parent
            width: parent.width - 6
            spacing: 1
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: button.label
                textFormat: Text.PlainText
                color: "#101418"
                font.pixelSize: 10
            }
            ActionFeedback {
                id: feedback
                width: parent.width
                actionKey: button.actionKey
            }
        }
        TapHandler { enabled: button.enabled; onTapped: button.triggered() }
    }

    component WorkspaceAction: Rectangle {
        id: button
        required property string windowId
        required property string workspaceId
        required property string label
        property bool current: false
        property bool available: false
        readonly property string actionKey:
            "window:" + windowId + ":move:" + workspaceId
        signal triggered
        objectName: "windowMove:" + windowId + ":" + workspaceId
        width: Math.max(62, Math.min(110, workspaceLabel.implicitWidth + 20))
        height: 42
        radius: 10
        enabled: available && !current && !root.blocked
        activeFocusOnTab: enabled
        color: current ? (root.colors.surface || "#2a2e33")
            : (root.colors.accent || "#8ab4f8")
        Accessible.role: Accessible.Button
        Accessible.name: current ? "Current workspace " + label
            : "Move to workspace " + label
        Accessible.description: feedback.text.length ? feedback.text : Accessible.name
        Accessible.ignored: !enabled
        Keys.onReturnPressed: triggered()
        Keys.onSpacePressed: triggered()
        Accessible.onPressAction: { if (enabled) triggered(); }

        Column {
            anchors.centerIn: parent
            width: parent.width - 8
            spacing: 1
            Text {
                id: workspaceLabel
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: button.label
                textFormat: Text.PlainText
                color: button.current
                    ? (root.colors.textSecondary || "#bdc1c6") : "#101418"
                font.pixelSize: 10
                elide: Text.ElideRight
            }
            ActionFeedback {
                id: feedback
                width: parent.width
                actionKey: button.actionKey
            }
        }
        TapHandler { enabled: button.enabled; onTapped: button.triggered() }
    }
}
