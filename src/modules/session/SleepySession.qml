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
                readonly property string actionId: "session:" + modelData.id
                readonly property var feedback:
                    (root.outputState.actionFeedback || ({}))[actionId] || ({})
                readonly property string actionStatus:
                    feedback.status || root.outputState.actionStatus(actionId)
                readonly property string actionDiagnostic:
                    feedback.diagnostic || root.outputState.actionDiagnostic(actionId)
                readonly property bool feedbackVisible:
                    ["pending", "rejected", "timeout"].indexOf(actionStatus) >= 0
                objectName: "sessionAction:" + modelData.id
                width: 154
                height: 58
                radius: 13
                enabled: !root.blocked && root.outputState.sessionAvailable
                activeFocusOnTab: enabled
                color: root.pendingAction === modelData.id
                    ? (root.colors.accent || "#8ab4f8")
                    : (root.colors.surface || "#2a2e33")
                Accessible.role: Accessible.Button
                Accessible.name: root.pendingAction === modelData.id
                    ? "Confirm " + modelData.label : modelData.label
                Accessible.description: feedbackVisible ? actionDiagnostic : Accessible.name
                signal triggered
                onTriggered: root.requestAction(String(modelData.id))
                Keys.onReturnPressed: triggered()
                Keys.onSpacePressed: triggered()
                Keys.onEscapePressed: root.cancelConfirmation()
                Accessible.onPressAction: { if (enabled) triggered(); }
                Column {
                    anchors.centerIn: parent
                    width: parent.width - 16
                    spacing: 2
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: button.modelData.label
                        textFormat: Text.PlainText
                        color: root.pendingAction === button.modelData.id
                            ? "#101418" : (root.colors.textPrimary || "#f1f3f4")
                    }
                    Text {
                        objectName: "commandDiagnostic:" + button.actionId
                        width: parent.width
                        visible: button.feedbackVisible
                        horizontalAlignment: Text.AlignHCenter
                        text: button.actionDiagnostic
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: button.actionStatus === "pending"
                            ? (root.colors.textSecondary || "#bdc1c6") : "#f2b8b5"
                        font.pixelSize: 9
                        Accessible.role: Accessible.StaticText
                        Accessible.name: text
                    }
                }
                TapHandler { enabled: button.enabled; onTapped: button.triggered() }
            }
        }
    }
}
