import QtQuick 6.0
import QtTest 1.0
import "../../src/services" as Services
import "../../src/services/DesktopCommands.js" as DesktopCommands

TestCase {
    id: testCase

    name: "CommandClient"

    readonly property string requestId: "22222222-2222-4222-8222-222222222222"

    Component { id: protocolFactory; Services.DesktopCommandProtocol {
        generation: 42
        timeoutMs: 20
    } }

    function fresh() { return createTemporaryObject(protocolFactory, testCase); }

    function assertSendRejectedWithoutMutation(protocol, family, command) {
        const before = {
            "pendingRequestId": protocol.pendingRequestId,
            "queuedLine": protocol.queuedLine,
            "status": protocol.status,
            "errorString": protocol.errorString
        };

        verify(!protocol.send(family, command, requestId));

        compare(protocol.pendingRequestId, before.pendingRequestId);
        compare(protocol.queuedLine, before.queuedLine);
        compare(protocol.status, before.status);
        compare(protocol.errorString, before.errorString);
    }

    function test_send_serializes_v3_expected_generation_and_one_request_at_a_time() {
        const protocol = fresh();
        const command = DesktopCommands.session("lock");

        verify(protocol.send("session", command, requestId));
        const request = JSON.parse(protocol.queuedLine);

        compare(request.schemaVersion, 3);
        compare(request.requestId, requestId);
        compare(request.expectedGeneration, 42);
        compare(request.command.family, "session");
        compare(request.command.command, "lock");
        verify(!protocol.send("session", command,
                              "33333333-3333-4333-8333-333333333333"));
    }

    function test_response_correlation_rejects_wrong_request_id() {
        const protocol = fresh();
        protocol.pendingRequestId = requestId;

        verify(!protocol.acceptResponse(JSON.stringify({
            "schemaVersion": 3,
            "requestId": "33333333-3333-4333-8333-333333333333",
            "generation": 43,
            "status": "succeeded"
        })));

        compare(protocol.status, "error");
    }

    function test_timeout_fails_pending_request() {
        const protocol = fresh();
        protocol.pendingRequestId = requestId;
        protocol.responseTimeout.restart();

        wait(40);

        compare(protocol.status, "error");
        compare(protocol.pendingRequestId, "");
        verify(protocol.errorString.indexOf("timed out") >= 0);
    }

    function test_successful_response_is_one_shot() {
        const protocol = fresh();
        protocol.pendingRequestId = requestId;
        const response = JSON.stringify({
            "schemaVersion": 3,
            "requestId": requestId,
            "generation": 43,
            "status": "succeeded"
        });

        verify(protocol.acceptResponse(response));
        compare(protocol.pendingRequestId, "");
        verify(!protocol.acceptResponse(response));
    }

    function test_send_rejects_builder_independent_malformed_commands_before_mutation_data() {
        const longId = "x".repeat(257);
        return [
            {
                "tag": "session command must be exact enum",
                "family": "session",
                "command": "unlock"
            },
            {
                "tag": "system command rejects out of range numbers",
                "family": "system",
                "command": {
                    "domain": "audio",
                    "action": {
                        "type": "setNodeVolume",
                        "data": {"nodeId": "speaker", "level": 1.5}
                    }
                }
            },
            {
                "tag": "system command rejects oversized stable ids",
                "family": "system",
                "command": {
                    "domain": "network",
                    "action": {
                        "type": "connectWifi",
                        "data": {"accessPointId": longId}
                    }
                }
            },
            {
                "tag": "compositor command rejects extra fields",
                "family": "compositor",
                "command": {"type": "exit", "extra": true}
            },
            {
                "tag": "notification command rejects invalid action ids",
                "family": "notification",
                "command": {
                    "type": "invokeAction",
                    "data": {"notificationId": 7, "actionId": "bad" + String.fromCharCode(1)}
                }
            },
            {
                "tag": "launcher command rejects malformed resources",
                "family": "launcher",
                "command": {
                    "type": "launch",
                    "data": {
                        "schemaVersion": 2,
                        "desktopId": "org.sleepy.Test.desktop",
                        "resources": [""]
                    }
                }
            },
            {
                "tag": "utility command rejects malformed output ids",
                "family": "utility",
                "command": {
                    "type": "screenshot",
                    "data": {"outputId": "shot" + String.fromCharCode(0)}
                }
            }
        ];
    }

    function test_send_rejects_builder_independent_malformed_commands_before_mutation(data) {
        assertSendRejectedWithoutMutation(fresh(), data.family, data.command);
    }
}
