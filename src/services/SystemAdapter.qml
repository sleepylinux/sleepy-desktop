import QtQuick 6.0
import Quickshell.Io

SystemAdapterCore {
    id: root
    property int timeoutMs: 1800
    property int pollIntervalMs: 3000
    property bool loadOnStartup: true
    property int snapshotGeneration: 0
    property int mutationGeneration: 0
    property int sessionGeneration: 0
    property bool snapshotTimedOut: false
    property bool mutationTimedOut: false
    property bool sessionTimedOut: false
    property bool refreshAfterCurrent: false

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
        if (mutationProcess.running) return false;
        const command = root.beginMutation(capability, value);
        if (!command) return false;
        root.mutationGeneration = root.nextGeneration;
        root.mutationTimedOut = false;
        mutationProcess.exec(command);
        mutationTimeout.restart();
        return true;
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

    Component.onCompleted: { if (root.loadOnStartup) Qt.callLater(root.refresh); }
    onImmediateRefreshRequested: Qt.callLater(root.requestImmediateRefresh)

    readonly property Timer pollTimer: Timer {
        interval: Math.max(3000, root.pollIntervalMs)
        repeat: true
        running: root.loadOnStartup
        onTriggered: root.refresh()
    }
    readonly property Process snapshotProcess: Process {
        stdout: StdioCollector { id: snapshotOut }
        stderr: StdioCollector { id: snapshotErr }
        onExited: exitCode => {
            root.snapshotTimeout.stop();
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
            root.acceptSnapshotResult(root.snapshotGeneration, -1, "", "", true);
        }
    }
    readonly property Process mutationProcess: Process {
        stdout: StdioCollector { id: mutationOut }
        stderr: StdioCollector { id: mutationErr }
        onExited: exitCode => {
            root.mutationTimeout.stop();
            if (!root.mutationTimedOut)
                root.acceptMutationResult(root.mutationGeneration, exitCode,
                    mutationOut.text, mutationErr.text, false);
        }
    }
    readonly property Timer mutationTimeout: Timer {
        interval: root.timeoutMs
        onTriggered: {
            root.mutationTimedOut = true;
            root.mutationProcess.signal(15);
            root.acceptMutationResult(root.mutationGeneration, -1, "", "", true);
        }
    }
    readonly property Process sessionProcess: Process {
        stdout: StdioCollector { id: sessionOut }
        stderr: StdioCollector { id: sessionErr }
        onExited: exitCode => {
            root.sessionTimeout.stop();
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
            root.acceptSessionResult(root.sessionGeneration, -1, "", "", true);
        }
    }
}
