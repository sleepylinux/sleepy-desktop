import QtQuick 6.0
import QtTest 1.0
import "../../src/services" as Services

TestCase {
    id: testCase

    name: "DesktopClientLifecycle"

    Component { id: policyFactory; Services.DesktopReconnectPolicy {} }
    Component { id: signalSpy; SignalSpy {} }

    function fresh() { return createTemporaryObject(policyFactory, testCase); }

    function test_clean_disconnect_schedules_bounded_reconnect() {
        const policy = fresh();
        const spy = signalSpy.createObject(policy, {
            target: policy,
            signalName: "disconnected"
        });

        verify(policy.handleSocketDisconnected("closed cleanly"));

        compare(spy.count, 1);
        compare(spy.signalArguments[0][0], "closed cleanly");
        compare(policy.reconnectAttempt, 1);
        compare(policy.reconnectTimer.interval, 250);
        verify(policy.reconnectTimer.running);
    }

    function test_repeated_disconnect_signal_does_not_create_duplicate_backoff_loop() {
        const policy = fresh();

        verify(policy.handleSocketDisconnected("closed cleanly"));
        verify(policy.handleSocketDisconnected("second signal"));

        compare(policy.reconnectAttempt, 1);
        compare(policy.reconnectTimer.interval, 250);
        verify(policy.reconnectTimer.running);
    }
}
