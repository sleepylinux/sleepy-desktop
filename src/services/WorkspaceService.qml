import QtQuick 6.0
import Quickshell
import Quickshell.Io

WorkspaceModel {
    id: root

    property int pollIntervalMs: 1500

    function refresh() {
        if (workspaceProcess.running)
            return false;
        workspaceProcess.exec(["niri", "msg", "--json", "workspaces"]);
        return true;
    }

    function focusWorkspace(index) {
        if (!Number.isFinite(Number(index)))
            return false;
        Quickshell.execDetached([
            "niri", "msg", "action", "focus-workspace", String(index)
        ]);
        return true;
    }

    Component.onCompleted: Qt.callLater(root.refresh)

    readonly property Process workspaceProcess: Process {
        stdout: StdioCollector { id: workspaceOutput }
        stderr: StdioCollector { id: workspaceError }

        onExited: exitCode => {
            if (exitCode === 0)
                root.acceptWorkspaces(workspaceOutput.text);
            else
                console.warn("Sleepy desktop: niri workspace query failed: "
                             + workspaceError.text.trim());
        }
    }

    readonly property Timer pollTimer: Timer {
        interval: root.pollIntervalMs
        repeat: true
        running: true
        onTriggered: root.refresh()
    }
}
