import QtQuick 6.0

QtObject {
    id: root
    required property var surfaceController
    property var actionRegistry: ActionRegistry {}
    property int nextQueryGeneration: 0
    property int activeQueryGeneration: 0
    property string diagnostic: ""
    property int queryTimeoutMs: 900
    signal focusedOutputQueryRequested(int generation)
    signal sessionActionRequested(string action, string outputName)

    function beginFocusedOutputQuery() {
        root.nextQueryGeneration += 1;
        root.activeQueryGeneration = root.nextQueryGeneration;
        root.focusedOutputQueryRequested(root.activeQueryGeneration);
        return ["niri", "msg", "--json", "focused-output"];
    }

    function acceptFocusedOutputResult(generation, exitCode, stdoutText, timedOut) {
        if (generation !== root.activeQueryGeneration)
            return false;
        if (timedOut || exitCode !== 0) {
            root.diagnostic = timedOut ? "Focused-output query timed out"
                                       : "Focused-output query failed";
            return false;
        }
        try {
            const document = JSON.parse(stdoutText);
            const name = typeof document === "string" ? document
                : document && typeof document.name === "string" ? document.name : "";
            if (!name.length)
                throw new Error("missing output name");
            root.diagnostic = "";
            return name;
        } catch (error) {
            root.diagnostic = "Malformed focused-output response";
            return false;
        }
    }

    function routeOnOutput(action, outputName) {
        const descriptor = root.actionRegistry.descriptor(action);
        if (!descriptor || typeof outputName !== "string" || !outputName.length)
            return false;
        if (descriptor.kind === "surface" && descriptor.method === "toggleControlCenter")
            return root.surfaceController.toggle("controlCenter", outputName);
        if (descriptor.kind === "surface" && descriptor.method === "openPowerMenu") {
            return root.surfaceController.requestPowerMenu(outputName);
        }
        if (descriptor.kind === "session") {
            root.sessionActionRequested(descriptor.action, outputName);
            return true;
        }
        return false;
    }
}
