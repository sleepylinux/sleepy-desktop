// SPDX-License-Identifier: GPL-3.0-only
// Modified for Sleepy on 2026-08-31: recording requests go through desktop-control.sock.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "DesktopCommands.js" as DesktopCommands

Singleton {
    id: root

    readonly property var recording: DesktopModel.capabilityData(
        "utilities", "recording", {"status": "inactive"})
    readonly property bool running: recording.status === "recording" || recording.status === "paused"
    readonly property bool paused: recording.status === "paused"
    property real elapsed: 0
    readonly property bool available: DesktopModel.capabilityAvailable("utilities", "recording")
    readonly property bool selecting: selection.running
    property string selectedOutput
    property bool selectedAudio

    function start(extraArgs = []): void {
        if (!root.available || root.running || root.selecting)
            return;
        const region = extraArgs.some(arg => arg.includes("r"));
        const withAudio = extraArgs.some(arg => arg.includes("s"));
        const outputId = String(Hypr.focusedMonitor?.name ?? "");
        if (!outputId.length)
            return;
        const target = region ? "region" : "output";
        if (region) {
            root.selectedOutput = outputId;
            root.selectedAudio = withAudio;
            selection.running = true;
            return;
        }
        root.requestRecording(outputId, target, withAudio);
    }

    function requestRecording(outputId, target, withAudio, region): void {
        const command = DesktopCommands.utilityStartRecording(outputId, target, withAudio, region);
        if (command && CommandClient.utility(command)) {
            root.elapsed = 0;
        }
    }

    Process {
        id: selection
        command: ["slurp", "-f", "%wx%h+%x+%y"]
        property string result: ""
        onStarted: result = ""
        stdout: StdioCollector { onStreamFinished: selection.result = text }
        onExited: (code, status) => {
            if (code !== 0 || status !== 0)
                return;
            const region = DesktopCommands.parseRecordingRegion(result);
            if (region)
                root.requestRecording(root.selectedOutput, "region", root.selectedAudio, region);
        }
    }

    function deleteRecording(path: string): void {
        const encodedName = String(path).split("/").pop();
        const recordingId = decodeURIComponent(encodedName || "");
        const command = DesktopCommands.utilityDeleteRecording(recordingId);
        if (command)
            CommandClient.utility(command);
    }

    function stop(): void {
        CommandClient.utility(DesktopCommands.utilityStopRecording());
    }

    function togglePause(): void {
        CommandClient.utility(DesktopCommands.utilityPauseRecording());
    }

    Connections {
        function onSecondsChanged(): void {
            if (root.running && !root.paused)
                root.elapsed++;
        }

        target: Time
    }
}
