import QtQuick 6.0
import QtTest 1.0
import "../../src/services" as Services

TestCase {
    id: testCase

    name: "DesktopProtocol"

    Component {
        id: protocolFactory

        Services.DesktopProtocol {}
    }

    function freshProtocol() {
        const protocol = createTemporaryObject(protocolFactory, testCase);
        protocol.minimumRetryMs = 250;
        protocol.maximumRetryMs = 10000;
        return protocol;
    }

    function envelope(generation) {
        return {
            "schemaVersion": 3,
            "generation": generation,
            "eventId": "11111111-1111-4111-8111-111111111111",
            "emittedAt": "2026-08-31T00:00:00Z",
            "cause": { "kind": "external" },
            "payload": { "type": "fullSnapshot", "data": {} }
        };
    }

    function test_generation_accepts_safe_integer_beyond_qml_int32() {
        const protocol = freshProtocol();

        verify(protocol.acceptEnvelope(envelope(4294967296)));

        compare(protocol.generation, 4294967296);
        compare(protocol.connectionState, "ready");
    }

    function test_generation_rejects_values_outside_javascript_safe_integer_range() {
        const protocol = freshProtocol();

        verify(!protocol.acceptEnvelope(envelope(9007199254740992)));

        compare(protocol.connectionState, "error");
    }

    function test_retry_delay_is_bounded_between_protocol_limits() {
        const protocol = freshProtocol();

        compare(protocol.boundedRetryDelay(0), 250);
        compare(protocol.boundedRetryDelay(99), 10000);
    }
}
