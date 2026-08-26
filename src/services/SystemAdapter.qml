import QtQuick 6.0
import Quickshell.Io

SystemAdapterCore {
    id: root
    property int timeoutMs: 1800
    property int pollIntervalMs: 3000
    property bool loadOnStartup: true
    property int snapshotGeneration: 0
    property int sessionGeneration: 0
    property bool snapshotTimedOut: false
    property bool sessionTimedOut: false
    property bool refreshAfterCurrent: false
    property var eventSource: null
    property var controlClient: null

    function refresh() {
        if (snapshotProcess.running) return false;
        const command = root.beginSnapshot();
        root.snapshotGeneration = root.nextGeneration;
        root.snapshotTimedOut = false;
        snapshotProcess.exec(command);
        snapshotTimeout.restart();
        return true;
    }
    function requestImmediateRefresh() {
        if (snapshotProcess.running) {
            root.refreshAfterCurrent = true;
            return;
        }
        root.refresh();
    }
    function mutate(capability, value) {
        if (!root.controlClient) return false;
        const sent = root.controlClient.sendMutation(capability, value);
        if (sent) root.mutationCapabilityBusy = capability;
        return sent;
    }
    function perform(action, confirmation) {
        if (sessionProcess.running) return false;
        const command = root.beginSessionAction(action, confirmation);
        if (!command) return false;
        root.sessionGeneration = root.nextGeneration;
        root.sessionTimedOut = false;
        sessionProcess.exec(command);
        sessionTimeout.restart();
        return true;
    }

    Component.onCompleted: {
        root.runtimeStreamRequired = root.eventSource !== null;
        root.runtimeStreamReady = !root.runtimeStreamRequired
            || root.eventSource.connectionState === "ready";
        if (root.loadOnStartup && !root.eventSource) Qt.callLater(root.refresh);
    }
    onEventSourceChanged: {
        root.runtimeStreamRequired = root.eventSource !== null;
        root.runtimeStreamReady = !root.runtimeStreamRequired
            || root.eventSource.connectionState === "ready";
    }
    readonly property Connections eventConnections: Connections {
        target: root.eventSource
        enabled: root.eventSource !== null
        function onEventAccepted(envelope) { root.acceptRuntimeEvents(root.eventSource); }
        function onConnectionStateChanged() {
            root.runtimeStreamReady = root.eventSource.connectionState === "ready";
            if (!root.runtimeStreamReady) {
                root.available = false;
                root.diagnostic = root.eventSource.diagnostic || "Session event stream unavailable";
            }
        }
    }
    readonly property Connections controlConnections: Connections {
        target: root.controlClient
        enabled: root.controlClient !== null
        function onMutationCompleted() { root.mutationCapabilityBusy = ""; }
        function onStatusChanged() {
            if (root.controlClient.status === "error") {
                root.mutationCapabilityBusy = "";
                root.diagnostic = root.controlClient.errorString;
            }
        }
    }
    onImmediateRefreshRequested: Qt.callLater(root.requestImmediateRefresh)

    readonly property Timer pollTimer: Timer {
        interval: Math.max(3000, root.pollIntervalMs)
        repeat: true
        running: root.loadOnStartup && root.eventSource === null
        onTriggered: root.refresh()
    }
    readonly property Process snapshotProcess: Process {
        stdout: StdioCollector { id: snapshotOut }
        stderr: StdioCollector { id: snapshotErr }
        onExited: exitCode => {
            root.snapshotTimeout.stop();
            root.snapshotKillTimeout.stop();
            if (!root.snapshotTimedOut)
                root.acceptSnapshotResult(root.snapshotGeneration, exitCode,
                    snapshotOut.text, snapshotErr.text, false);
            if (root.refreshAfterCurrent) {
                root.refreshAfterCurrent = false;
                Qt.callLater(root.refresh);
            }
        }
    }
    readonly property Timer snapshotTimeout: Timer {
        interval: root.timeoutMs
        onTriggered: {
            root.snapshotTimedOut = true;
            root.snapshotProcess.signal(15);
            root.snapshotKillTimeout.restart();
            root.acceptSnapshotResult(root.snapshotGeneration, -1, "", "", true);
        }
    }
    readonly property Timer snapshotKillTimeout: Timer {
        interval: 1000
        onTriggered: if (root.snapshotProcess.running) root.snapshotProcess.signal(9)
    }
    readonly property Process sessionProcess: Process {
        stdout: StdioCollector { id: sessionOut }
        stderr: StdioCollector { id: sessionErr }
        onExited: exitCode => {
            root.sessionTimeout.stop();
            root.sessionKillTimeout.stop();
            if (!root.sessionTimedOut)
                root.acceptSessionResult(root.sessionGeneration, exitCode,
                    sessionOut.text, sessionErr.text, false);
        }
    }
    readonly property Timer sessionTimeout: Timer {
        interval: root.timeoutMs
        onTriggered: {
            root.sessionTimedOut = true;
            root.sessionProcess.signal(15);
            root.sessionKillTimeout.restart();
            root.acceptSessionResult(root.sessionGeneration, -1, "", "", true);
        }
    }
    readonly property Timer sessionKillTimeout: Timer {
        interval: 1000
        onTriggered: if (root.sessionProcess.running) root.sessionProcess.signal(9)
    }
}
