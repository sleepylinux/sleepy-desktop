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
        const outputId = extraArgs.indexOf("-s") >= 0 ? "selection" : "active";
        const command = DesktopCommands.utilityStartRecording(outputId);
        if (command && CommandClient.utility(command)) {
            root.elapsed = 0;
        }
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
