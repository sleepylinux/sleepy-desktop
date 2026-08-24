import QtQuick 6.0
import Quickshell.Io

PresetAdapterCore {
    id: root
    property int timeoutMs: 1800
    property bool loadOnStartup: true
    property var activeCommand: null
    property bool timedOut: false
    signal commandRejected(string reason)

    function run(command) {
        if (!command || process.running) return false;
        root.activeCommand = command;
        root.busy = true;
        root.timedOut = false;
        process.exec(command);
        timeout.restart();
        return true;
    }
    function refresh() { return root.run(root.listCommand()); }
    function activate(id) { return root.run(root.activateCommand(id)); }
    function duplicate(source, name) { return root.run(root.duplicateCommand(source, name)); }
    function rename(id, name) { return root.run(root.renameCommand(id, name)); }
    function remove(id) { return root.run(root.deleteCommand(id)); }
    function setBinding(id, action, accelerator, apply) {
        return root.run(root.setBindingCommand(id, action, accelerator, apply));
    }

    Component.onCompleted: { if (root.loadOnStartup) Qt.callLater(root.refresh); }

    readonly property Process process: Process {
        stdout: StdioCollector { id: output }
        stderr: StdioCollector { id: errorOutput }
        onExited: exitCode => {
            root.timeout.stop();
            if (root.timedOut) return;
            const isList = root.activeCommand && root.activeCommand.length >= 3
                && root.activeCommand[1] === "presets" && root.activeCommand[2] === "list";
            const isExport = root.activeCommand && root.activeCommand.length >= 3
                && root.activeCommand[1] === "presets" && root.activeCommand[2] === "export";
            if (isExport) {
                root.acceptExportResult(exitCode, output.text, errorOutput.text, false);
                return;
            }
            const accepted = isList
                ? root.acceptListResult(exitCode, output.text, errorOutput.text, false)
                : root.acceptCommandResult(root.activeCommand, exitCode,
                    output.text, errorOutput.text, false);
            if (accepted && !isList) Qt.callLater(root.refresh);
        }
    }
    readonly property Timer timeout: Timer {
        interval: root.timeoutMs
        onTriggered: {
            root.timedOut = true;
            root.process.signal(15);
            const isList = root.activeCommand && root.activeCommand[2] === "list";
            const isExport = root.activeCommand && root.activeCommand[2] === "export";
            if (isList) root.acceptListResult(-1, "", "", true);
            else if (isExport) root.acceptExportResult(-1, "", "", true);
            else root.acceptMutationResult(-1, "", "", true);
        }
    }
}
