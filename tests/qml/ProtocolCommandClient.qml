import QtQuick 6.0
import "../../src/services" as Services

QtObject {
    id: root

    property int generation: 1
    property int requestSerial: 1
    property alias busy: protocol.busy
    property alias status: protocol.status
    property alias errorString: protocol.errorString
    property alias pendingRequestId: protocol.pendingRequestId
    property alias timeoutMs: protocol.timeoutMs

    signal commandCompleted(var result)
    signal commandFailed(string message)

    function nextRequestId() {
        const suffix = String(root.requestSerial++).padStart(12, "0");
        return "11111111-1111-4111-8111-" + suffix;
    }

    function send(family, command) {
        return protocol.send(family, command, root.nextRequestId());
    }

    function system(command) { return root.send("system", command); }
    function compositor(command) { return root.send("compositor", command); }
    function notification(command) { return root.send("notification", command); }
    function launcher(command) { return root.send("launcher", command); }
    function appearance(command) { return root.send("appearance", command); }
    function utility(command) { return root.send("utility", command); }
    function session(command) { return root.send("session", command); }

    function acceptFailedResponse(message) {
        return protocol.acceptResponse(JSON.stringify({
            "schemaVersion": 3,
            "requestId": protocol.pendingRequestId,
            "generation": root.generation,
            "status": "failed",
            "diagnostic": {"message": String(message)}
        }));
    }

    function acceptSuccess() {
        return protocol.acceptResponse(JSON.stringify({
            "schemaVersion": 3,
            "requestId": protocol.pendingRequestId,
            "generation": root.generation,
            "status": "succeeded"
        }));
    }

    readonly property list<QtObject> implementation: [
        Services.DesktopCommandProtocol {
            id: protocol
            generation: root.generation
            onCommandCompleted: result => root.commandCompleted(result)
            onCommandFailed: message => root.commandFailed(message)
        }
    ]
}
