import QtQuick 6.0
import QtTest 1.0
import "../../src/services" as Services

TestCase {
    id: testCase
    name: "PresetAdapterCore"
    Component { id: factory; Services.PresetAdapterCore {} }

    function fixture(name) {
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl("../fixtures/" + name), false);
        request.send();
        return request.responseText;
    }
    function fresh() { return createTemporaryObject(factory, testCase); }

    function test_presets_are_strictly_parsed_and_disambiguated() {
        const adapter = fresh();
        compare(adapter.listCommand().join(" "), "sleepyctl presets list");
        verify(adapter.acceptListResult(0, fixture("presets-valid.json"), "", false));
        compare(adapter.presets.length, 2);
        compare(adapter.displayName(adapter.presets[1]), "Night work · 42db48b6");
        compare(adapter.canEdit(adapter.presets[0]), false);
        compare(adapter.canEdit(adapter.presets[1]), true);
    }

    function test_malformed_result_preserves_last_valid_list() {
        const adapter = fresh();
        adapter.acceptListResult(0, fixture("presets-valid.json"), "", false);
        const stable = adapter.presets;
        verify(!adapter.acceptListResult(0, '{"presets":[{"id":"x"}]}', "", false));
        compare(adapter.presets, stable);
    }

    function test_crud_and_binding_commands_match_session_contract() {
        const adapter = fresh();
        compare(adapter.duplicateCommand("builtin.sleepy", "My copy").join(" "),
                "sleepyctl presets duplicate builtin.sleepy My copy");
        compare(adapter.renameCommand("user-id", "Deep work").join(" "),
                "sleepyctl presets rename user-id Deep work");
        compare(adapter.activateCommand("user-id").join(" "),
                "sleepyctl presets activate user-id --apply");
        compare(adapter.deleteCommand("user-id").join(" "),
                "sleepyctl presets delete user-id");
        compare(adapter.setBindingCommand("user-id", "app.terminal.open", "Mod+Return", true).join(" "),
                "sleepyctl keybindings set --preset user-id app.terminal.open Mod+Return --apply");
        compare(adapter.importCommand("/tmp/preset.json", "copy", true), null);
        compare(adapter.importCommand("/tmp/preset.json", "replace", true).join(" "),
                "sleepyctl presets import --input /tmp/preset.json --mode replace --apply");
    }

    function test_structured_conflict_names_both_actions() {
        const adapter = fresh();
        verify(!adapter.acceptMutationResult(3, "", JSON.stringify({
            error: {
                code: "keybinding_conflict",
                message: "Duplicate keybinding conflict for Mod+C",
                details: {
                    kind: "duplicate", accelerator: "Mod+C",
                    actions: ["surface.controlCenter.toggle", "app.terminal.open"]
                }
            }
        }), false));
        verify(adapter.conflictMessage.indexOf("surface.controlCenter.toggle") >= 0);
        verify(adapter.conflictMessage.indexOf("app.terminal.open") >= 0);
        compare(adapter.conflictActions.join(" "),
                "surface.controlCenter.toggle app.terminal.open");
    }

    function test_confirmed_activation_updates_active_preset() {
        const adapter = fresh();
        adapter.activePresetId = "builtin.sleepy";
        verify(adapter.acceptCommandResult(
            adapter.activateCommand("user-id"), 0, fixture("apply-committed.json"),
            "", false));
        compare(adapter.activePresetId, "user-id");
    }

    function test_apply_report_closed_statuses_never_claim_attempted_activation() {
        const reports = [
            ["rolledBackConfirmed", "apply-rolled-back-confirmed.json"],
            ["commitStateUnknown", "apply-commit-state-unknown.json"],
            ["reloadPending", "apply-reload-pending.json"]
        ];
        for (let i = 0; i < reports.length; ++i) {
            const adapter = fresh();
            adapter.activePresetId = "builtin.sleepy";
            verify(!adapter.acceptCommandResult(adapter.activateCommand("user-id"), 0,
                fixture(reports[i][1]), "", false));
            compare(adapter.activePresetId, "builtin.sleepy");
            verify(adapter.diagnostic.indexOf(reports[i][0]) >= 0);
            compare(adapter.refreshRequired, false);
            const diagnostic = adapter.diagnostic;
            verify(adapter.acceptListResult(0, fixture("presets-valid.json"), "", false));
            compare(adapter.diagnostic, diagnostic);
            compare(adapter.activePresetId, "builtin.sleepy");
        }
    }

    function test_apply_report_rejects_unknown_fields_and_wrong_active_id() {
        const adapter = fresh();
        adapter.activePresetId = "builtin.sleepy";
        verify(!adapter.acceptCommandResult(adapter.activateCommand("user-id"), 0,
            '{"status":"committed","activePresetId":"other","extra":true}', "", false));
        compare(adapter.activePresetId, "builtin.sleepy");
        verify(!adapter.acceptCommandResult(adapter.activateCommand("user-id"), 0,
            '{"status":"committed","activePresetId":"other"}', "", false));
        compare(adapter.activePresetId, "builtin.sleepy");
    }

    function test_builtin_binding_apply_uses_atomic_task3_command_and_report_id() {
        const adapter = fresh();
        adapter.activePresetId = "builtin.sleepy";
        const command = adapter.setBindingCommand(
            "builtin.sleepy", "app.terminal.open", "Mod+T", true);
        compare(command.join(" "),
            "sleepyctl keybindings set --preset builtin.sleepy app.terminal.open Mod+T --apply");
        verify(adapter.acceptCommandResult(command, 0,
            '{"status":"committed","activePresetId":"dd4d415e-5af0-4c12-aaf4-69e5bb893a61"}',
            "", false));
        compare(adapter.activePresetId, "dd4d415e-5af0-4c12-aaf4-69e5bb893a61");
    }

    function test_confirmed_duplicate_exposes_update_safe_copy_for_editing() {
        const adapter = fresh();
        adapter.acceptListResult(0, fixture("presets-valid.json"), "", false);
        const copy = JSON.parse(fixture("presets-valid.json")).presets[1];
        copy.id = "dd4d415e-5af0-4c12-aaf4-69e5bb893a61";
        copy.name = "Sleepy copy";
        const spy = signalSpy.createObject(adapter,
            {target: adapter, signalName: "copyCreated"});
        verify(adapter.acceptCommandResult(
            adapter.duplicateCommand("builtin.sleepy", "Sleepy copy"), 0,
            JSON.stringify({preset: copy}), "", false));
        compare(spy.count, 1);
        compare(spy.signalArguments[0][0], copy.id);
        compare(adapter.presets[adapter.presets.length - 1].id, copy.id);
    }

    Component { id: signalSpy; SignalSpy {} }

    function test_export_result_is_strict_and_retrievable() {
        const adapter = fresh();
        const preset = JSON.parse(fixture("presets-valid.json")).presets[1];
        verify(adapter.acceptExportResult(0, JSON.stringify(preset), "", false));
        verify(adapter.lastExportJson.indexOf('"name": "Night work"') >= 0);
        const stable = adapter.lastExportJson;
        verify(!adapter.acceptExportResult(0,
            JSON.stringify(Object.assign({}, preset, {unknown: true})), "", false));
        compare(adapter.lastExportJson, stable);
    }

    function test_import_apply_is_derived_from_document_target_not_selection() {
        const adapter = fresh();
        adapter.activePresetId = "42db48b6-70c7-4fca-b36f-90658bdfba41";
        const active = JSON.parse(fixture("presets-valid.json")).presets[1];
        compare(adapter.importCommandForDocument(
            "/tmp/active.json", "replace", JSON.stringify(active)).join(" "),
            "sleepyctl presets import --input /tmp/active.json --mode replace --apply");
        active.id = "dd4d415e-5af0-4c12-aaf4-69e5bb893a61";
        compare(adapter.importCommandForDocument(
            "/tmp/inactive.json", "replace", JSON.stringify(active)).join(" "),
            "sleepyctl presets import --input /tmp/inactive.json --mode replace");
        compare(adapter.importCommandForDocument(
            "/tmp/bad.json", "replace", '{"id":"missing"}'), null);
    }
}
