// SPDX-License-Identifier: GPL-3.0-only
pragma Singleton
import QtQuick 6.0
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property var job: protocol.job
    readonly property var capabilities: protocol.capabilities
    readonly property string errorString: protocol.errorString
    readonly property bool active: protocol.active
    readonly property bool busy: protocol.busy
    property bool transportPending: false
    property bool started: false
    property bool exited: false
    property bool streamDone: false
    property int exitCode: -1
    property string response: ""
    property string transportError: ""

    function begin(outputId, jobId) {
        const id = jobId || "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, c => {
            const value = Math.floor(Math.random() * 16);
            return (c === "x" ? value : (value & 3) | 8).toString(16);
        });
        return protocol.begin(outputId, id);
    }
    function cancel() { return protocol.cancel(); }
    function refreshCapabilities() { return protocol.refreshCapabilities(); }
    function finishTransport() {
        if (!transportPending || !exited || !streamDone) return;
        transportPending = false; deadline.stop();
        if (transportError.length) protocol.transportFailed(transportError);
        else if (exitCode === 0) protocol.accept(response);
        else protocol.transportFailed("Capture service request failed");
    }
    function failedTransport(message) {
        if (!transportPending) return;
        transportError = message; deadline.stop();
        if (started && !exited) {
            // Do not release protocol serialization until the old process and
            // output stream have actually finished. Its reply cannot race reuse.
            transport.signal(9);
        } else if (!started) {
            exited = streamDone = true;
            finishTransport();
        }
    }
    CaptureJobsProtocol {
        id: protocol
        onRequestReady: request => {
            root.started = root.exited = root.streamDone = false;
            root.exitCode = -1; root.response = ""; root.transportError = ""; root.transportPending = true;
            transport.command = ["sleepyctl", "capture", "request", JSON.stringify(request)];
            deadline.restart(); transport.running = true;
        }
    }
    Process {
        id: transport
        onStarted: root.started = true
        onRunningChanged: {
            if (!running && root.transportPending && !root.started)
                root.failedTransport("Capture client could not start");
        }
        stdout: StdioCollector {
            onStreamFinished: {
                root.response = text; root.streamDone = true;
                Qt.callLater(root.finishTransport);
            }
        }
        onExited: (code, status) => {
            root.exitCode = status === 0 ? code : -1; root.exited = true;
            Qt.callLater(root.finishTransport);
        }
    }
    Timer {
        id: deadline
        interval: 3000
        onTriggered: root.failedTransport("Capture service request timed out")
    }
    Timer {
        interval: 500
        repeat: true
        running: protocol.active && !protocol.busy && !root.transportPending
        onTriggered: protocol.status()
    }
}
