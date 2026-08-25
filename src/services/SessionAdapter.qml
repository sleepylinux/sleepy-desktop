import QtQuick 6.0
import Quickshell.Io

SessionAdapterCore {
    id: root

    property int timeoutMs: 1800
    property bool loadOnStartup: true
    property bool settingsRequestTimedOut: false
    property bool activationRequestTimedOut: false

    function refresh() {
        if (settingsProcess.running)
            return false;
        root.settingsRequestTimedOut = false;
        settingsProcess.exec(root.beginSettingsRead());
        settingsTimeout.restart();
        return true;
    }

    function activatePreset(presetId) {
        const command = root.activationCommand(presetId);
        if (command.length === 0 || activationProcess.running)
            return false;
        root.busy = true;
        root.activationRequestTimedOut = false;
        activationProcess.exec(command);
        activationTimeout.restart();
        return true;
    }

    Component.onCompleted: {
        if (root.loadOnStartup)
            Qt.callLater(root.refresh);
    }

    readonly property Process settingsProcess: Process {
        stdout: StdioCollector { id: settingsOutput }
        stderr: StdioCollector { id: settingsError }

        onExited: exitCode => {
            root.settingsTimeout.stop();
            root.settingsKillTimeout.stop();
            if (!root.settingsRequestTimedOut)
                root.acceptSettingsResult(exitCode, settingsOutput.text,
                                          settingsError.text, false);
        }
    }

    readonly property Timer settingsTimeout: Timer {
        interval: root.timeoutMs
        repeat: false
        onTriggered: {
            root.settingsRequestTimedOut = true;
            root.settingsProcess.signal(15);
            root.settingsKillTimeout.restart();
            root.acceptSettingsResult(-1, "", "", true);
        }
    }
    readonly property Timer settingsKillTimeout: Timer {
        interval: 1000
        repeat: false
        onTriggered: if (root.settingsProcess.running) root.settingsProcess.signal(9)
    }

    readonly property Process activationProcess: Process {
        stdout: StdioCollector { id: activationOutput }
        stderr: StdioCollector { id: activationError }

        onExited: exitCode => {
            root.activationTimeout.stop();
            root.activationKillTimeout.stop();
            if (!root.activationRequestTimedOut)
                root.acceptActivationResult(exitCode, activationOutput.text,
                                            activationError.text, false);
        }
    }

    readonly property Timer activationTimeout: Timer {
        interval: root.timeoutMs
        repeat: false
        onTriggered: {
            root.activationRequestTimedOut = true;
            root.activationProcess.signal(15);
            root.activationKillTimeout.restart();
            root.acceptActivationResult(-1, "", "", true);
        }
    }
    readonly property Timer activationKillTimeout: Timer {
        interval: 1000
        repeat: false
        onTriggered: if (root.activationProcess.running) root.activationProcess.signal(9)
    }
}
