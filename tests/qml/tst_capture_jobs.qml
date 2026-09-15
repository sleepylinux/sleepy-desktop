import QtQuick 6.0
import QtTest 1.0
import "../../src/services" as Services

TestCase {
    id: testCase
    name: "CaptureJobs"
    Component { id: factory; Services.CaptureJobsProtocol {} }
    readonly property string jobId: "22222222-2222-4222-8222-222222222222"
    function fresh() { return createTemporaryObject(factory, testCase); }
    function reply(state) {
        const job = {jobId: jobId, outputId: "output:DP-1", state: state};
        if (state === "completed") job.result = {path: "/run/user/1000/sleepy/captures/screenshot-" + jobId + ".png", mimeType: "image/png", width: 20, height: 30};
        return {schemaVersion: 1, payload: {type: "job", job: job}};
    }
    function test_begin_ack_is_not_completion() {
        const p = fresh(); verify(p.begin("output:DP-1", jobId));
        verify(!p.begin("output:DP-2", jobId));
        verify(p.accept(JSON.stringify(reply("awaitingConsent"))));
        verify(p.active); compare(p.job.state, "awaitingConsent"); verify(!p.job.result);
        verify(p.status()); verify(p.accept(JSON.stringify(reply("capturing")))); verify(p.active);
        verify(p.status()); verify(p.accept(JSON.stringify(reply("completed"))));
        verify(!p.active); compare(p.job.result.width, 20); verify(!p.status());
    }
    function test_invalid_completion_never_publishes_result() {
        for (const mutate of [j => j.result.path = "/tmp/a.png", j => j.result.width = 0,
                j => j.result.path = j.result.path.replace(jobId, "33333333-3333-4333-8333-333333333333"),
                j => j.extra = true, j => j.jobId = "33333333-3333-4333-8333-333333333333",
                j => j.outputId = "output:DP-2", j => j.result.mimeType = "text/plain"]) {
            const p = fresh(); verify(p.begin("output:DP-1", jobId));
            const value = reply("completed"); mutate(value.payload.job);
            verify(!p.accept(JSON.stringify(value))); verify(!p.job || !p.job.result);
        }
    }
    function test_cancellation_while_begin_pending_waits_for_reply() {
        const p = fresh(); verify(p.begin("output:DP-1", jobId)); verify(p.cancel());
        compare(p.pendingCommand.type, "begin");
        verify(p.accept(JSON.stringify(reply("awaitingConsent"))));
        tryCompare(p, "busy", true); compare(p.pendingCommand.type, "cancel");
        verify(p.accept(JSON.stringify(reply("cancelled")))); verify(!p.active); compare(p.job.state, "cancelled");
    }
    function test_malformed_transport_never_replays_begin() {
        const p = fresh(); verify(p.begin("output:DP-1", jobId));
        verify(!p.accept("not json")); verify(p.active); verify(p.status()); compare(p.pendingCommand.type, "status");
    }
    function test_closed_schema_and_frame_bounds() {
        const p = fresh(); verify(p.begin("output:DP-1", jobId));
        const value = reply("awaitingConsent"); value.payload.job.result = null;
        verify(!p.accept(JSON.stringify(value)));
        verify(p.status()); verify(!p.accept(" ".repeat(4097)));
        verify(!p.begin("output:../../bad", jobId));
    }
}
