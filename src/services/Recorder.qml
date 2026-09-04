// SPDX-License-Identifier: GPL-3.0-only
// Modified for Sleepy on 2026-08-31: recording requests go through desktop-control.sock.

pragma Singleton

import QtQuick
import Quickshell
import "DesktopCommands.js" as DesktopCommands

Singleton {
    id: root

    readonly property var recording: DesktopModel.capabilityData(
        "utilities", "recording", {"status": "inactive"})
    readonly property bool running: recording.status === "recording" || recording.status === "paused"
    readonly property bool paused: recording.status === "paused"
    property real elapsed: 0

    function start(extraArgs = []): void {
        const region = extraArgs.some(arg => arg.includes("r"));
        const withAudio = extraArgs.some(arg => arg.includes("s"));
        const outputId = String(Hypr.focusedMonitor?.name ?? "");
        if (!outputId.length)
            return;
        const command = DesktopCommands.utilityStartRecording(outputId, withAudio);
        if (command && CommandClient.utility(command)) {
            root.elapsed = 0;
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
