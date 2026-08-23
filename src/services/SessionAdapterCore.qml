import QtQuick 6.0
import "SettingsCodec.js" as SettingsCodec

QtObject {
    id: root

    property string executable: "sleepyctl"
    property var settings: SettingsCodec.defaultSettings()
    property bool available: false
    property bool busy: false
    property string diagnostic: "Sleepy session has not responded; using immutable defaults"

    signal settingsAccepted
    signal diagnosticRaised(string message)

    function fallback(message) {
        root.settings = SettingsCodec.defaultSettings();
        root.available = false;
        root.busy = false;
        root.diagnostic = message;
        root.diagnosticRaised(message);
        console.warn("Sleepy desktop: " + message);
    }

    function beginSettingsRead() {
        root.busy = true;
        return [root.executable, "settings", "show"];
    }

    function acceptDocumentResult(commandLabel, exitCode, stdoutText, stderrText, timedOut) {
        root.busy = false;
        if (timedOut) {
            root.fallback(commandLabel + " timed out; using immutable defaults");
            return false;
        }
        if (exitCode !== 0) {
            const detail = String(stderrText).trim();
            root.fallback(commandLabel + " failed with exit " + exitCode
                          + (detail.length > 0 ? ": " + detail : "")
                          + "; using immutable defaults");
            return false;
        }

        try {
            root.settings = SettingsCodec.parseSettings(stdoutText);
            root.available = true;
            root.diagnostic = "";
            root.settingsAccepted();
            return true;
        } catch (error) {
            root.fallback("sleepyctl returned malformed settings (" + error.message
                          + "); using immutable defaults");
            return false;
        }
    }

    function acceptSettingsResult(exitCode, stdoutText, stderrText, timedOut) {
        return root.acceptDocumentResult("sleepyctl settings show", exitCode, stdoutText,
                                         stderrText, timedOut);
    }

    function activationCommand(presetId) {
        if (typeof presetId !== "string" || presetId.trim().length === 0)
            return [];
        return [root.executable, "presets", "activate", presetId];
    }

    function acceptActivationResult(exitCode, stdoutText, stderrText, timedOut) {
        return root.acceptDocumentResult("sleepyctl presets activate", exitCode, stdoutText,
                                         stderrText, timedOut);
    }
}
