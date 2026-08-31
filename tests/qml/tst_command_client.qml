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
}
