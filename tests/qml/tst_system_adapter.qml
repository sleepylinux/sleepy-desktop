import QtQuick 6.0
import QtTest 1.0
import "../../src/services" as Services

TestCase {
    id: testCase
    name: "SystemAdapterCore"

    Component { id: factory; Services.SystemAdapterCore {} }

    function fixture(name) {
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl("../fixtures/" + name), false);
        request.send();
        return request.responseText;
    }

    function fresh() { return createTemporaryObject(factory, testCase); }

    function test_show_command_uses_client_generation() {
        const adapter = fresh();
        compare(adapter.beginSnapshot().join(" "),
                "sleepyctl system show --generation 1");
        compare(adapter.beginSnapshot().join(" "),
                "sleepyctl system show --generation 2");
    }

    function test_valid_snapshot_is_accepted_without_optimistic_state() {
        const adapter = fresh();
        const request = adapter.beginSnapshot();
        compare(adapter.snapshot, null);
        verify(adapter.acceptSnapshotResult(1, 0,
            fixture("system-valid.json").replace('"generation": 7', '"generation": 1'), "", false));
        compare(adapter.snapshot.network.connectedName, "Sleepy Wi-Fi");
        compare(adapter.snapshot.audio.outputDevices[0].id, "sink.living-room");
        compare(adapter.lastAcceptedGeneration, 1);
        compare(adapter.busy, false);
    }

    function test_malformed_timeout_and_nonzero_preserve_last_valid_snapshot() {
        const adapter = fresh();
        adapter.beginSnapshot();
        verify(adapter.acceptSnapshotResult(1, 0,
            fixture("system-valid.json").replace('"generation": 7', '"generation": 1'), "", false));
        const stable = adapter.snapshot;

        adapter.beginSnapshot();
        verify(!adapter.acceptSnapshotResult(2, 0, "{broken", "", false));
        compare(adapter.snapshot, stable);
        verify(adapter.diagnostic.indexOf("malformed") >= 0);

        adapter.beginSnapshot();
        verify(!adapter.acceptSnapshotResult(3, -1, "", "", true));
        compare(adapter.snapshot, stable);
        verify(adapter.diagnostic.indexOf("timed out") >= 0);

        adapter.beginSnapshot();
        verify(!adapter.acceptSnapshotResult(4, 5, "", "adapter failed", false));
        compare(adapter.snapshot, stable);
        verify(adapter.diagnostic.indexOf("adapter failed") >= 0);
    }

    function test_stale_and_unknown_documents_never_replace_state() {
        const adapter = fresh();
        adapter.beginSnapshot();
        verify(adapter.acceptSnapshotResult(1, 0,
            fixture("system-valid.json").replace('"generation": 7', '"generation": 1'), "", false));
        const stable = adapter.snapshot;
        verify(!adapter.acceptSnapshotResult(0, 0,
            fixture("system-valid.json").replace('"generation": 7', '"generation": 0'), "", false));
        compare(adapter.snapshot, stable);
        verify(!adapter.acceptSnapshotResult(8, 0,
            fixture("system-valid.json").replace('"media":', '"unknown": true, "media":'), "", false));
        compare(adapter.snapshot, stable);
    }

    function test_newer_failure_makes_older_late_success_stale() {
        const adapter = fresh();
        adapter.beginSnapshot();
        adapter.beginSnapshot();
        verify(!adapter.acceptSnapshotResult(2, 5, "", "newer failed", false));
        verify(!adapter.acceptSnapshotResult(1, 0,
            fixture("system-valid.json").replace('"generation": 7', '"generation": 1'),
            "", false));
        compare(adapter.snapshot, null);
        compare(adapter.lastCompletedGeneration, 2);
    }

    function test_busy_and_pending_tracking_cover_parallel_processes_without_growth() {
        const adapter = fresh();
        adapter.beginSnapshot();
        adapter.beginMutation("audio.volume", 0.3);
        adapter.beginSessionAction("lock", "confirmed");
        compare(adapter.pendingCount, 3);
        compare(Object.keys(adapter.pendingKinds).length, 3);
        compare(adapter.busy, true);

        verify(!adapter.acceptSessionResult(3, 5, "", "failed", false));
        compare(adapter.pendingCount, 2);
        compare(adapter.busy, true);
        verify(!adapter.acceptMutationResult(2, 5, "", "stale", false));
        compare(adapter.pendingCount, 1);
        compare(adapter.busy, true);
        verify(!adapter.acceptSnapshotResult(1, 5, "", "stale", false));
        compare(adapter.pendingCount, 0);
        compare(Object.keys(adapter.pendingKinds).length, 0);
        compare(adapter.busy, false);
    }

    function test_mutation_is_typed_and_refreshes_only_after_confirmed_readback() {
        const adapter = fresh();
        const command = adapter.beginMutation("audio.volume", 0.3);
        compare(command.join(" "),
                "sleepyctl system set audio.volume 0.3 --generation 1");
        compare(adapter.snapshot, null);
        verify(adapter.acceptMutationResult(1, 0, JSON.stringify({
            schemaVersion: 1,
            generation: 1,
            mutation: {capability: "audio.volume", value: 0.3},
            snapshot: JSON.parse(fixture("system-valid.json")
                .replace('"generation": 7', '"generation": 1')
                .replace('"volume": 0.62', '"volume": 0.3'))
        }), "", false));
        compare(adapter.snapshot.audio.volume, 0.3);
        verify(adapter.refreshRequested);
    }

    function test_mutation_rejects_unknown_fields_and_unconfirmed_snapshot() {
        const adapter = fresh();
        adapter.beginMutation("audio.volume", 0.3);
        const snapshot = JSON.parse(fixture("system-valid.json")
            .replace('"generation": 7', '"generation": 1'));
        const unknown = {
            schemaVersion: 1, generation: 1,
            mutation: {capability: "audio.volume", value: 0.3, extra: true},
            snapshot: snapshot
        };
        verify(!adapter.acceptMutationResult(1, 0, JSON.stringify(unknown), "", false));
        compare(adapter.snapshot, null);

        adapter.beginMutation("audio.volume", 0.3);
        snapshot.generation = 2;
        const unconfirmed = {
            schemaVersion: 1, generation: 2,
            mutation: {capability: "audio.volume", value: 0.3},
            snapshot: snapshot
        };
        verify(!adapter.acceptMutationResult(2, 0, JSON.stringify(unconfirmed), "", false));
        compare(adapter.snapshot, null);
    }

    function test_session_action_requires_closed_name_and_confirmation() {
        const adapter = fresh();
        compare(adapter.beginSessionAction("powerOff", "confirmed").join(" "),
                "sleepyctl session perform powerOff confirmed --generation 1");
        compare(adapter.beginSessionAction("powerOff", ""), null);
        compare(adapter.beginSessionAction("sleep", "confirmed"), null);
    }

    function test_session_result_enforces_status_diagnostic_pair() {
        const adapter = fresh();
        adapter.beginSessionAction("logout", "confirmed");
        verify(adapter.acceptSessionResult(1, 0, JSON.stringify({
            schemaVersion: 1, generation: 1, action: "logout",
            status: "initiated", diagnostic: null
        }), "", false));

        adapter.beginSessionAction("reboot", "confirmed");
        verify(!adapter.acceptSessionResult(2, 0, JSON.stringify({
            schemaVersion: 1, generation: 2, action: "reboot",
            status: "initiated", diagnostic: {kind: "command", message: "unexpected"}
        }), "", false));

        adapter.beginSessionAction("powerOff", "confirmed");
        verify(!adapter.acceptSessionResult(3, 0, JSON.stringify({
            schemaVersion: 1, generation: 3, action: "powerOff",
            status: "failed", diagnostic: null
        }), "", false));
    }
}
