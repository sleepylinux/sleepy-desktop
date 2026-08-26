// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0
import Quickshell.Io

SessionEventModel {
    id: root
    property string executable: "sleepyctl"
    property bool enabled: true
    property int reconnectAttempt: 0
    property bool stoppingProcess: false
    readonly property int reconnectDelayMs: Math.min(10000, 250 * Math.pow(2, reconnectAttempt))

    function connectStream() {
        if (!root.enabled || eventProcess.running) return false;
        root.beginConnection();
        eventProcess.exec([root.executable, "events", "watch", "--format", "ndjson"]);
        return true;
    }
    function scheduleReconnect(message) {
        root.disconnected(message);
        if (root.enabled) reconnectTimer.restart();
    }
    function stopProcess() {
        if (!eventProcess.running) return false;
        root.stoppingProcess = true;
        eventProcess.signal(15);
        processKillTimeout.restart();
        return true;
    }
    Component.onCompleted: if (enabled) Qt.callLater(connectStream)
    onEnabledChanged: {
        if (enabled) Qt.callLater(connectStream);
        else root.stopProcess();
    }

    readonly property Process eventProcess: Process {
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (String(data).trim().length === 0) return;
                if (root.acceptLine(data)) root.reconnectAttempt = 0;
                else root.stopProcess();
            }
        }
        stderr: StdioCollector { id: eventErrors; waitForEnd: false }
        onExited: (exitCode, exitStatus) => {
            root.processKillTimeout.stop();
            root.stoppingProcess = false;
            if (!root.enabled) return;
            root.reconnectAttempt = Math.min(6, root.reconnectAttempt + 1);
            const detail = eventErrors.text.trim();
            root.scheduleReconnect("Event stream exited " + exitCode
                                   + (detail.length ? ": " + detail : ""));
        }
    }
    readonly property Timer processKillTimeout: Timer {
        interval: 1000
        repeat: false
        onTriggered: if (root.eventProcess.running) root.eventProcess.signal(9)
    }
    readonly property Timer reconnectTimer: Timer {
        interval: root.reconnectDelayMs
        repeat: false
        onTriggered: root.connectStream()
    }
}
