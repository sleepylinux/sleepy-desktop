import QtQuick 6.0
import QtTest 1.0
import "../../src/services" as Services

TestCase {
    id: testCase
    name: "LockRequest"
    Component { id: factory; Item {
        property alias protocol: protocol
        property alias lock: lock
        property alias failures: failures
        Services.DesktopCommandProtocol {
            id: protocol; generation: 42; timeoutMs: 1000
            onResponseAccepted: result => lock.handleResult(result)
            onCommandFailed: message => lock.handleFailure(message)
        }
        Services.LockRequest { id: lock; protocol: protocol; ready: true; generation: protocol.generation; timeoutMs: 1000 }
        SignalSpy { id: failures; target: lock; signalName: "failed" }
    } }
    function fresh() { return createTemporaryObject(factory, testCase); }
    function respond(f, status, generation, message) {
        const result = {schemaVersion: 3, requestId: f.protocol.pendingRequestId, generation: generation, status: status};
        if (status === "failed") result.diagnostic = {message: message};
        f.protocol.acceptResponse(JSON.stringify(result));
    }
    function test_waits_for_ready_snapshot_and_coalesces_lock() {
        const f = fresh(); f.lock.ready = false;
        verify(f.lock.request()); verify(f.lock.request());
        compare(f.protocol.queuedLine, ""); verify(f.lock.pending);
        f.protocol.generation = 80; f.lock.ready = true;
        tryVerify(() => f.protocol.busy);
        const request = JSON.parse(f.protocol.queuedLine);
        compare(request.expectedGeneration, 80); compare(request.command.command, "lock");
        respond(f, "succeeded", 81); verify(!f.lock.pending); compare(f.failures.count, 0);
    }
    function test_stale_retries_once_after_current_snapshot_with_new_id() {
        const f = fresh(); verify(f.lock.request());
        const firstId = f.protocol.pendingRequestId;
        respond(f, "failed", 50, "request.generation-stale");
        wait(1); verify(f.lock.pending); verify(!f.protocol.busy);
        f.lock.ready = false; f.protocol.generation = 51; wait(1); verify(!f.protocol.busy);
        f.lock.ready = true; tryVerify(() => f.protocol.busy);
        verify(f.protocol.pendingRequestId !== firstId);
        compare(JSON.parse(f.protocol.queuedLine).expectedGeneration, 51);
        respond(f, "succeeded", 52); verify(!f.lock.pending); compare(f.failures.count, 0);
    }
    function test_second_stale_is_reported_and_never_replayed() {
        const f = fresh(); verify(f.lock.request());
        respond(f, "failed", 43, "request.generation-stale");
        f.protocol.generation = 44; tryVerify(() => f.protocol.busy);
        respond(f, "failed", 45, "request.generation-stale");
        compare(f.failures.count, 1); verify(!f.lock.pending);
        f.protocol.generation = 46; wait(1); verify(!f.protocol.busy);
    }
    function test_transport_failure_is_not_replayed() {
        const f = fresh(); verify(f.lock.request()); f.protocol.fail("Desktop control service unavailable");
        compare(f.failures.count, 1); verify(!f.lock.pending);
        f.protocol.generation = 60; wait(1); verify(!f.protocol.busy);
    }
    function test_missing_snapshot_expires_without_sending() {
        const f = fresh(); f.lock.ready = false; f.lock.timeoutMs = 20;
        verify(f.lock.request()); tryCompare(f.failures, "count", 1);
        verify(!f.lock.pending); compare(f.protocol.queuedLine, "");
        f.lock.ready = true; wait(1); verify(!f.protocol.busy);
    }
    function test_response_timeout_is_not_replayed() {
        const f = fresh(); f.protocol.timeoutMs = 20;
        verify(f.lock.request()); tryCompare(f.failures, "count", 1);
        verify(!f.lock.pending); f.protocol.generation = 60; wait(1); verify(!f.protocol.busy);
    }
    function test_other_action_stale_is_not_replayed() {
        for (const action of ["reboot", "suspend", "hibernate", "suspendThenHibernate", "logout", "powerOff"]) {
            const f = fresh();
            verify(f.protocol.send("session", action, "22222222-2222-4222-8222-222222222222"));
            respond(f, "failed", 50, "request.generation-stale");
            f.protocol.generation = 51; wait(1); verify(!f.protocol.busy); verify(!f.lock.pending);
        }
    }
    function test_pending_expiry_does_not_cancel_another_command() {
        const f = fresh();
        verify(f.protocol.send("session", "reboot", "22222222-2222-4222-8222-222222222222"));
        f.lock.timeoutMs = 20; verify(f.lock.request());
        tryCompare(f.failures, "count", 1); verify(f.protocol.busy);
        compare(JSON.parse(f.protocol.queuedLine).command.command, "reboot");
    }
    function test_disconnect_during_request_is_terminal_not_replayed() {
        const f = fresh(); verify(f.lock.request());
        f.lock.ready = false; f.protocol.fail("Desktop control service unavailable");
        compare(f.failures.count, 1); verify(!f.lock.pending);
        f.protocol.generation = 60; f.lock.ready = true; wait(1); verify(!f.protocol.busy);
    }
    function test_whole_intent_deadline_is_not_reset_after_stale() {
        const f = fresh(); f.lock.timeoutMs = 80;
        verify(f.lock.request()); wait(50);
        respond(f, "failed", 60, "request.generation-stale");
        tryCompare(f.failures, "count", 1, 60); verify(!f.lock.pending);
    }

    function test_explicit_ids_are_not_coalesced_or_rewritten() {
        const f = fresh(); f.lock.ready = false;
        const id = "22222222-2222-4222-8222-222222222222";
        verify(!f.lock.request(id)); verify(!f.lock.pending);
        verify(f.lock.request()); verify(!f.lock.request(id));
        compare(f.protocol.queuedLine, "");
    }
    function test_explicit_lock_protocol_remains_correlated_one_shot() {
        const f = fresh();
        const id = "22222222-2222-4222-8222-222222222222";
        const other = "33333333-3333-4333-8333-333333333333";
        verify(f.protocol.send("session", "lock", id));
        verify(!f.protocol.send("session", "lock", other));
        compare(f.protocol.pendingRequestId, id);
        respond(f, "failed", 50, "request.generation-stale");
        compare(f.protocol.lastResult.requestId, id);
        f.protocol.generation = 51; wait(1);
        verify(!f.protocol.busy); verify(!f.lock.pending);
    }

}
