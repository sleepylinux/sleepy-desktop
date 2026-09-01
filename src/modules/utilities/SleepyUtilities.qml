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
            label: root.idleInhibited ? "Allow idle" : "Keep awake"
            available: root.outputState.idleInhibitAvailable
            onTriggered: root.requestIdleInhibited(!root.idleInhibited)
        }
        ActionButton {
            objectName: "utilityRecording"
            label: root.recordingState.status === "recording" ? "Pause recording"
                : root.recordingState.status === "paused" ? "Stop recording" : "Record"
            available: root.outputState.recordingAvailable
            onTriggered: root.requestRecording()
        }
        ActionButton {
            objectName: "utilityScreenshot"
            label: "Screenshot / area"
            available: root.outputState.screenshotAvailable
            onTriggered: root.requestScreenshot()
        }
        ActionButton {
            objectName: "utilityColorPicker"
            label: "Pick colour"
            available: root.outputState.colorPickerAvailable
            onTriggered: root.requestColorPicker()
        }
        ActionButton {
            objectName: "utilityGameMode"
            label: root.gameMode ? "Disable game mode" : "Game mode"
            available: root.outputState.gameModeAvailable
            onTriggered: root.requestGameMode(!root.gameMode)
        }
    }

    component ActionButton: Rectangle {
        id: button
        required property string label
        property bool available: true
        signal triggered
        width: 154
        height: 42
        radius: 13
        enabled: available && !root.blocked
        activeFocusOnTab: enabled
        color: enabled ? (root.colors.surface || "#2a2e33") : "#303030"
        opacity: enabled ? 1 : 0.58
        Accessible.role: Accessible.Button
        Accessible.name: label
        Accessible.description: enabled ? label : "Unavailable"
        Keys.onReturnPressed: triggered()
        Keys.onSpacePressed: triggered()
        Accessible.onPressAction: {
            if (enabled)
                triggered();
        }
        Text {
            anchors.centerIn: parent
            width: parent.width - 16
            text: button.label
            textFormat: Text.PlainText
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            color: root.colors.textPrimary || "#f1f3f4"
        }
        TapHandler { enabled: button.enabled; onTapped: button.triggered() }
    }
}
