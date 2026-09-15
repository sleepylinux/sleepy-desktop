import QtQuick 6.0
import QtTest 1.0
import "../../src/services" as Services

TestCase {
    id: testCase
    name: "CaptureJobState"
    Component { id: factory; Item {
        property alias job: job
        property alias exits: exits
        Services.CaptureJobState { id: job }
        SignalSpy { id: exits; target: job; signalName: "exitRequested" }
    } }
    function test_consent_and_successful_write_are_both_required() {
        const f = createTemporaryObject(factory, testCase);
        verify(f.job.begin()); verify(!f.job.completed(true, 20, 30));
        compare(f.job.state, "awaitingConsent"); compare(f.exits.count, 0);
        verify(f.job.consent()); compare(f.exits.count, 0);
        verify(f.job.completed(true, 20, 30)); compare(f.job.state, "completed"); compare(f.exits.count, 1);
    }
    function test_cancel_ignores_late_write_completion() {
        const f = createTemporaryObject(factory, testCase);
        f.job.begin(); f.job.consent(); verify(f.job.cancel());
        verify(!f.job.completed(true, 20, 30)); compare(f.job.state, "cancelled"); compare(f.exits.count, 1);
    }
    function test_failed_write_never_becomes_completed() {
        const f = createTemporaryObject(factory, testCase);
        f.job.begin(); f.job.consent(); verify(f.job.completed(false, 0, 0));
        compare(f.job.state, "failed"); compare(f.exits.signalArguments[0][0], 1);
    }
}
