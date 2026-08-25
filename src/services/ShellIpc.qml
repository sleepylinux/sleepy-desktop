import QtQuick 6.0
import Quickshell

Scope {
    id: root
    required property var shortcutRouter
    required property var surfaceController
    required property var eventSource
    property string pendingMethod: ""
    property string pendingArgument: ""
    property var requestQueue: ([])
    property bool queryActive: false
    property string diagnostic: ""

    function request(method, argument) {
        const queue = root.requestQueue.slice();
        queue.push({"method": method, "argument": argument || ""});
        root.requestQueue = queue;
        root.startNext();
        return true;
    }
    function startNext() {
        if (root.queryActive || !root.requestQueue.length)
            return false;
        const queue = root.requestQueue.slice();
        const next = queue.shift();
        root.requestQueue = queue;
        root.pendingMethod = next.method;
        root.pendingArgument = next.argument;
        root.queryActive = true;
        const output = root.eventSource.focusedOutputId;
        if (!output || root.eventSource.connectionState !== "ready") {
            root.diagnostic = "Focused output unavailable from session event stream";
            root.queryActive = false;
            Qt.callLater(root.startNext);
            return false;
        }
        root.finishQuery(output);
        root.queryActive = false;
        Qt.callLater(root.startNext);
        return true;
    }
    function finishQuery(output) {
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
}
