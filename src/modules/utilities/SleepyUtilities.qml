// SPDX-License-Identifier: GPL-3.0-only
// Sleepy rewrite of the upstream v2.4.0 utility cards for strict desktop v3.

pragma ComponentBehavior: Bound

import QtQuick 6.0

Column {
    id: root
    objectName: "task10Utilities"

    required property var outputState
    required property var colors
    readonly property bool idleInhibited: Boolean(root.outputState.idleInhibited)
    readonly property bool gameMode: Boolean(root.outputState.gameMode)
    readonly property var recordingState: root.outputState.recordingState || ({"status": "inactive"})
    readonly property bool blocked: Boolean(root.outputState.busy)
    spacing: 8

    function requestIdleInhibited(enabled) {
        return !root.blocked && root.outputState.idleInhibitAvailable
            && root.outputState.setIdleInhibited(Boolean(enabled));
    }

    function requestRecording() {
        if (root.blocked || !root.outputState.recordingAvailable)
            return false;
        if (root.recordingState.status === "recording")
            return root.outputState.pauseRecording();
        if (root.recordingState.status === "paused")
            return root.outputState.stopRecording();
        return root.outputState.startRecording();
    }

    function requestStopRecording() {
        return !root.blocked && root.outputState.recordingAvailable
            && root.recordingState.status !== "inactive"
            && root.outputState.stopRecording();
    }

    function requestScreenshot() {
        return !root.blocked && root.outputState.screenshotAvailable
            && root.outputState.takeScreenshot();
    }

    function requestColorPicker() {
        return !root.blocked && root.outputState.colorPickerAvailable
            && root.outputState.pickColor();
    }

    function requestGameMode(enabled) {
        return !root.blocked && root.outputState.gameModeAvailable
            && root.outputState.setGameMode(Boolean(enabled));
    }

    Text {
        text: "Utilities"
        textFormat: Text.PlainText
        color: root.colors.textPrimary || "#f1f3f4"
        font.bold: true
        Accessible.role: Accessible.Heading
        Accessible.name: text
    }

    Grid {
        columns: 2
        spacing: 7

        ActionButton {
            objectName: "utilityIdleInhibit"
            actionId: "utility:idleInhibit"
            label: root.idleInhibited ? "Allow idle" : "Keep awake"
            available: root.outputState.idleInhibitAvailable
            onTriggered: root.requestIdleInhibited(!root.idleInhibited)
        }
        ActionButton {
            objectName: "utilityRecording"
            actionId: "utility:recording"
            label: root.recordingState.status === "recording" ? "Pause recording"
                : root.recordingState.status === "paused" ? "Stop recording" : "Record"
            available: root.outputState.recordingAvailable
            onTriggered: root.requestRecording()
        }
        ActionButton {
            objectName: "utilityScreenshot"
            actionId: "utility:screenshot"
            label: "Screenshot / area"
            available: root.outputState.screenshotAvailable
            onTriggered: root.requestScreenshot()
        }
        ActionButton {
            objectName: "utilityColorPicker"
            actionId: "utility:colorPicker"
            label: "Pick colour"
            available: root.outputState.colorPickerAvailable
            onTriggered: root.requestColorPicker()
        }
        ActionButton {
            objectName: "utilityGameMode"
            actionId: "utility:gameMode"
            label: root.gameMode ? "Disable game mode" : "Game mode"
            available: root.outputState.gameModeAvailable
            onTriggered: root.requestGameMode(!root.gameMode)
        }
    }

    component ActionButton: Rectangle {
        id: button
        required property string actionId
        required property string label
        property bool available: true
        readonly property var feedback:
            (root.outputState.actionFeedback || ({}))[actionId] || ({})
        readonly property string actionStatus:
            feedback.status || root.outputState.actionStatus(actionId)
        readonly property string actionDiagnostic:
            feedback.diagnostic || root.outputState.actionDiagnostic(actionId)
        readonly property bool feedbackVisible:
            ["pending", "rejected", "timeout"].indexOf(actionStatus) >= 0
        signal triggered
        width: 154
        height: 58
        radius: 13
        enabled: available && !root.blocked
        activeFocusOnTab: enabled
        color: enabled ? (root.colors.surface || "#2a2e33") : "#303030"
        opacity: enabled ? 1 : 0.58
        Accessible.role: Accessible.Button
        Accessible.name: label
        Accessible.description: feedbackVisible ? actionDiagnostic
            : enabled ? label : "Unavailable"
        Keys.onReturnPressed: triggered()
        Keys.onSpacePressed: triggered()
        Accessible.onPressAction: {
            if (enabled)
                triggered();
        }
        Column {
            anchors.centerIn: parent
            width: parent.width - 16
            spacing: 2
            Text {
                width: parent.width
                text: button.label
                textFormat: Text.PlainText
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                color: root.colors.textPrimary || "#f1f3f4"
            }
            Text {
                objectName: "commandDiagnostic:" + button.actionId
                width: parent.width
                visible: button.feedbackVisible
                text: button.actionDiagnostic
                textFormat: Text.PlainText
                horizontalAlignment: Text.AlignHCenter
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
