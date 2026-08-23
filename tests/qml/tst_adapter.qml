import QtQuick 6.0
import QtTest 1.0
import "../../src/services" as Services

TestCase {
    id: testCase

    name: "SessionAdapter"

    Component {
        id: adapterFactory

        Services.SessionAdapterCore {}
    }

    function fixture(name) {
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl("../fixtures/" + name), false);
        request.send();
        verify(request.status === 0 || request.status === 200,
               "fixture should load: " + name);
        return request.responseText;
    }

    function freshAdapter() {
        return createTemporaryObject(adapterFactory, testCase);
    }

    function test_valid_settings_are_parsed_from_sleepyctl_output() {
        const adapter = freshAdapter();

        adapter.acceptSettingsResult(0, fixture("settings-valid.json"), "", false);

        compare(adapter.settings.appearanceMode, "light");
        compare(adapter.settings.effectsProfile, "reduced");
        compare(adapter.settings.reducedMotion, true);
        compare(adapter.settings.webSearchEnabled, false);
        compare(adapter.available, true);
        compare(adapter.diagnostic, "");
    }

    function test_unknown_keys_fall_back_with_a_diagnostic() {
        const adapter = freshAdapter();

        adapter.acceptSettingsResult(0, fixture("settings-extra-key.json"), "", false);

        compare(adapter.settings.appearanceMode, "dark");
        compare(adapter.settings.activePresetId, "builtin.sleepy");
        compare(adapter.available, false);
        verify(adapter.diagnostic.indexOf("unknown key") !== -1);
    }

    function test_malformed_output_falls_back_without_remaining_busy() {
        const adapter = freshAdapter();
        adapter.beginSettingsRead();

        adapter.acceptSettingsResult(0, fixture("settings-malformed.json"), "", false);

        compare(adapter.busy, false);
        compare(adapter.settings.appearanceMode, "dark");
        verify(adapter.diagnostic.indexOf("malformed") !== -1);
    }

    function test_timeout_and_nonzero_exit_have_specific_diagnostics() {
        const timedOut = freshAdapter();
        timedOut.beginSettingsRead();
        timedOut.acceptSettingsResult(-1, "", "", true);
        compare(timedOut.busy, false);
        verify(timedOut.diagnostic.indexOf("timed out") !== -1);

        const failed = freshAdapter();
        failed.acceptSettingsResult(4, "", "store unavailable", false);
        verify(failed.diagnostic.indexOf("exit 4") !== -1);
        verify(failed.diagnostic.indexOf("store unavailable") !== -1);
    }

    function test_commands_match_the_reviewed_cli_contract() {
        const adapter = freshAdapter();

        compare(adapter.beginSettingsRead().join(" "), "sleepyctl settings show");
        compare(adapter.activationCommand("builtin.sleepy").join(" "),
                "sleepyctl presets activate builtin.sleepy");
    }

    function test_activation_failure_names_the_mutating_command() {
        const adapter = freshAdapter();

        adapter.acceptActivationResult(7, "", "unknown preset", false);

        verify(adapter.diagnostic.indexOf("presets activate") !== -1);
        verify(adapter.diagnostic.indexOf("exit 7") !== -1);
        compare(adapter.settings.activePresetId, "builtin.sleepy");
    }

    function test_fallback_settings_cannot_be_mutated_by_consumers() {
        const adapter = freshAdapter();

        try {
            adapter.settings.appearanceMode = "light";
        } catch (error) {
            // A strict JS engine may throw while a non-strict engine ignores the write.
        }

        compare(adapter.settings.appearanceMode, "dark");
    }
}
