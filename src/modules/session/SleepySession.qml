// SPDX-License-Identifier: GPL-3.0-only
// Sleepy rewrite of the upstream v2.4.0 session menu for strict desktop v3.

pragma ComponentBehavior: Bound

import QtQuick 6.0

Column {
    id: root
    objectName: "task10Session"

    required property var outputState
    required property var colors
    property string pendingAction: ""
    readonly property bool blocked: Boolean(root.outputState.busy)
    spacing: 8

    function validAction(action) {
        return ["lock", "suspend", "logout", "reboot", "powerOff"].indexOf(action) >= 0;
    }

    function requestAction(action) {
        if (!root.validAction(action) || root.blocked || !root.outputState.sessionAvailable)
            return false;
        if (action === "lock") {
            root.pendingAction = "";
            return root.outputState.performSession(action);
        }
        if (root.pendingAction !== action) {
            root.pendingAction = action;
            return true;
        }
        root.pendingAction = "";
        return root.outputState.performSession(action);
    }

    function cancelConfirmation() {
        root.pendingAction = "";
    }

    Text {
        text: root.pendingAction.length
            ? "Confirm " + root.pendingAction : "Session"
        textFormat: Text.PlainText
        color: root.colors.textPrimary || "#f1f3f4"
        font.bold: true
        Accessible.role: Accessible.Heading
        Accessible.name: text
    }

    Grid {
        columns: 2
        spacing: 7
        Repeater {
            model: [
                {"id": "lock", "label": "Lock"},
                {"id": "suspend", "label": "Suspend"},
                {"id": "logout", "label": "Log out"},
                {"id": "reboot", "label": "Restart"},
                {"id": "powerOff", "label": "Power off"}
            ]
            delegate: Rectangle {
                id: button
                required property var modelData
                objectName: "sessionAction:" + modelData.id
                width: 154
                height: 42
                radius: 13
                enabled: !root.blocked && root.outputState.sessionAvailable
                activeFocusOnTab: enabled
                color: root.pendingAction === modelData.id
                    ? (root.colors.accent || "#8ab4f8")
                    : (root.colors.surface || "#2a2e33")
                Accessible.role: Accessible.Button
                Accessible.name: root.pendingAction === modelData.id
                    ? "Confirm " + modelData.label : modelData.label
                signal triggered
                onTriggered: root.requestAction(String(modelData.id))
                Keys.onReturnPressed: triggered()
                Keys.onSpacePressed: triggered()
                Keys.onEscapePressed: root.cancelConfirmation()
                Accessible.onPressAction: { if (enabled) triggered(); }
                Text {
                    anchors.centerIn: parent
                    text: button.modelData.label
                    textFormat: Text.PlainText
                    color: root.pendingAction === button.modelData.id
                        ? "#101418" : (root.colors.textPrimary || "#f1f3f4")
                }
                TapHandler { enabled: button.enabled; onTapped: button.triggered() }
            }
        }
    }
}
