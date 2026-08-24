import QtQuick 6.0
import Quickshell
import Quickshell.Io

Scope {
    id: root
    required property var shortcutRouter
    required property var surfaceController
    property string pendingMethod: ""
    property string pendingArgument: ""
    property int queryGeneration: 0
    property bool queryTimedOut: false
    property int queryTimeoutMs: 900
    property var requestQueue: ([])
    property bool queryActive: false

    function request(method, argument) {
        const queue = root.requestQueue.slice();
        queue.push({"method": method, "argument": argument || ""});
        root.requestQueue = queue;
        root.startNext();
        return true;
    }
    function startNext() {
        if (root.queryActive || focusedOutputProcess.running || !root.requestQueue.length)
            return false;
        const queue = root.requestQueue.slice();
        const next = queue.shift();
        root.requestQueue = queue;
        root.pendingMethod = next.method;
        root.pendingArgument = next.argument;
        root.queryActive = true;
        root.queryTimedOut = false;
        const command = root.shortcutRouter.beginFocusedOutputQuery();
        root.queryGeneration = root.shortcutRouter.activeQueryGeneration;
        focusedOutputProcess.exec(command);
        focusedOutputTimeout.restart();
        return true;
    }
    function finishQuery(exitCode, stdoutText, timedOut) {
        const output = root.shortcutRouter.acceptFocusedOutputResult(
            root.queryGeneration, exitCode, stdoutText, timedOut);
        if (!output) return false;
        if (root.pendingMethod === "toggle")
            return root.surfaceController.toggle("controlCenter", output);
        if (root.pendingMethod === "open")
            return root.surfaceController.open("controlCenter", output);
        if (root.pendingMethod === "close")
            return root.surfaceController.close(undefined, output);
        if (root.pendingMethod === "power") {
            return root.surfaceController.requestPowerMenu(output);
        }
        if (root.pendingMethod === "session")
            return root.shortcutRouter.routeOnOutput("session." + root.pendingArgument, output);
        return false;
    }

    IpcHandler {
        target: "sleepy"
        function toggleControlCenter(): void { root.request("toggle", ""); }
        function openControlCenter(): void { root.request("open", ""); }
        function closeActiveSurface(): void { root.request("close", ""); }
        function openPowerMenu(): void { root.request("power", ""); }
        function requestSessionAction(action: string): void {
            if (["lock", "logout", "reboot", "powerOff"].indexOf(action) >= 0)
                root.request("session", action);
        }
    }
    Process {
        id: focusedOutputProcess
        stdout: StdioCollector { id: focusedOutput }
        onExited: exitCode => {
            focusedOutputTimeout.stop();
            if (!root.queryTimedOut) root.finishQuery(exitCode, focusedOutput.text, false);
            root.queryActive = false;
            Qt.callLater(root.startNext);
        }
    }
    Timer {
        id: focusedOutputTimeout
        interval: root.queryTimeoutMs
        onTriggered: {
            root.queryTimedOut = true;
            focusedOutputProcess.signal(15);
            root.finishQuery(-1, "", true);
        }
    }
}
