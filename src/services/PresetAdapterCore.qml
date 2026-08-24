import QtQuick 6.0

QtObject {
    id: root

    property string executable: "sleepyctl"
    property var presets: Object.freeze([])
    property string activePresetId: ""
    property bool available: false
    property bool busy: false
    property string diagnostic: "Preset state has not been loaded"
    property string conflictMessage: ""
    property var conflictActions: Object.freeze([])
    property string lastExportJson: ""
    property bool refreshRequired: false
    property bool applyDiagnosticSticky: false

    signal presetsAccepted
    signal mutationAccepted
    signal diagnosticRaised(string message)
    signal exportReady(string json)
    signal copyCreated(string presetId)

    function own(object, key) {
        return Object.prototype.hasOwnProperty.call(object, key);
    }

    function exactKeys(object, required, optional) {
        if (!object || typeof object !== "object" || Array.isArray(object))
            return false;
        const allowed = required.concat(optional || []);
        const keys = Object.keys(object);
        return required.every(function(key) { return root.own(object, key); })
            && keys.every(function(key) { return allowed.indexOf(key) >= 0; });
    }

    function validString(value) {
        return typeof value === "string" && value.length > 0;
    }

    function validStringMap(value) {
        return value && typeof value === "object" && !Array.isArray(value)
            && Object.keys(value).every(function(key) {
                return root.validString(key) && root.validString(value[key]);
            });
    }

    function validPreset(preset) {
        if (!root.exactKeys(preset,
              ["schemaVersion", "id", "name", "origin", "keybindings",
               "drawers", "layouts", "pluginRequirements"], ["basePresetId"])
                || preset.schemaVersion !== 1 || !root.validString(preset.id)
                || !root.validString(preset.name)
                || ["builtin", "user"].indexOf(preset.origin) < 0
                || !root.validStringMap(preset.keybindings)
                || !preset.drawers || typeof preset.drawers !== "object"
                || Array.isArray(preset.drawers)
                || !preset.layouts || typeof preset.layouts !== "object"
                || Array.isArray(preset.layouts)
                || !Array.isArray(preset.pluginRequirements)
                || !preset.pluginRequirements.every(root.validString))
            return false;
        if (preset.origin === "builtin" && root.own(preset, "basePresetId"))
            return false;
        return !root.own(preset, "basePresetId") || root.validString(preset.basePresetId);
    }

    function listCommand() {
        root.busy = true;
        return [root.executable, "presets", "list"];
    }

    function duplicateCommand(sourceId, name) {
        return root.validString(sourceId) && root.validString(name)
            ? [root.executable, "presets", "duplicate", sourceId, name] : null;
    }

    function renameCommand(id, name) {
        return root.validString(id) && root.validString(name)
            ? [root.executable, "presets", "rename", id, name] : null;
    }

    function activateCommand(id) {
        return root.validString(id)
            ? [root.executable, "presets", "activate", id, "--apply"] : null;
    }

    function deleteCommand(id) {
        return root.validString(id)
            ? [root.executable, "presets", "delete", id] : null;
    }

    function exportCommand(id) {
        return root.validString(id)
            ? [root.executable, "presets", "export", id] : null;
    }

    function importCommand(path, mode, apply) {
        if (!root.validString(path) || ["reject", "copy", "replace"].indexOf(mode) < 0)
            return null;
        if (apply === true && mode !== "replace")
            return null;
        const command = [root.executable, "presets", "import", "--input", path,
                         "--mode", mode];
        if (apply === true)
            command.push("--apply");
        return command;
    }

    function importCommandForDocument(path, mode, jsonText) {
        try {
            const document = JSON.parse(jsonText);
            if (!root.validPreset(document))
                throw new Error("preset document contract mismatch");
            return root.importCommand(path, mode,
                mode === "replace" && document.id === root.activePresetId);
        } catch (error) {
            root.fail("Cannot import preset (" + error.message + ")");
            return null;
        }
    }

    function bindingListCommand(id) {
        return root.validString(id)
            ? [root.executable, "keybindings", "list", "--preset", id] : null;
    }

    function setBindingCommand(id, action, accelerator, apply) {
        if (![id, action, accelerator].every(root.validString))
            return null;
        const command = [root.executable, "keybindings", "set", "--preset", id,
                         action, accelerator];
        if (apply === true)
            command.push("--apply");
        return command;
    }

    function unsetBindingCommand(id, action, apply) {
        if (![id, action].every(root.validString))
            return null;
        const command = [root.executable, "keybindings", "unset", "--preset", id, action];
        if (apply === true)
            command.push("--apply");
        return command;
    }

    function acceptListResult(exitCode, stdoutText, stderrText, timedOut) {
        root.busy = false;
        if (timedOut)
            return root.fail("sleepyctl presets list timed out");
        if (exitCode !== 0)
            return root.fail("sleepyctl presets list failed with exit " + exitCode
                             + root.stderrDetail(stderrText));
        try {
            const document = JSON.parse(stdoutText);
            if (!root.exactKeys(document, ["presets"], [])
                    || !Array.isArray(document.presets)
                    || !document.presets.every(root.validPreset))
                throw new Error("preset collection contract mismatch");
            const ids = {};
            for (let i = 0; i < document.presets.length; ++i) {
                if (root.own(ids, document.presets[i].id))
                    throw new Error("duplicate preset identifier");
                ids[document.presets[i].id] = true;
            }
            root.presets = Object.freeze(document.presets);
            root.available = true;
            if (!root.applyDiagnosticSticky)
                root.diagnostic = "";
            root.conflictMessage = "";
            root.refreshRequired = false;
            root.presetsAccepted();
            return true;
        } catch (error) {
            return root.fail("sleepyctl presets list returned malformed output ("
                             + error.message + ")");
        }
    }

    function stderrDetail(stderrText) {
        const detail = String(stderrText).trim();
        return detail.length ? ": " + detail : "";
    }

    function fail(message) {
        root.busy = false;
        root.diagnostic = message;
        root.diagnosticRaised(message);
        return false;
    }

    function parseConflict(stderrText) {
        try {
            const document = JSON.parse(stderrText);
            if (!root.exactKeys(document, ["error"], [])
                    || !root.exactKeys(document.error,
                        ["code", "message", "details"], [])
                    || document.error.code !== "keybinding_conflict"
                    || typeof document.error.message !== "string"
                    || !document.error.message.trim().length)
                return "";
            const conflict = document.error.details;
            if (!root.exactKeys(conflict,
                    ["kind", "accelerator", "actions"], [])
                    || ["duplicate", "reserved", "invalid"].indexOf(conflict.kind) < 0
                    || !root.validString(conflict.accelerator)
                    || !Array.isArray(conflict.actions)
                    || !conflict.actions.length
                    || !conflict.actions.every(root.validString))
                return "";
            const actions = Array.isArray(conflict.actions) ? conflict.actions : [];
            root.conflictActions = Object.freeze(actions.slice());
            if (actions.length >= 2)
                return "Binding conflict: " + actions[0] + " and " + actions[1];
            return "Binding conflict: " + (conflict.action || conflict.kind);
        } catch (error) {
            return "";
        }
    }

    function acceptMutationResult(exitCode, stdoutText, stderrText, timedOut) {
        root.busy = false;
        root.conflictMessage = "";
        root.conflictActions = Object.freeze([]);
        if (timedOut)
            return root.fail("sleepyctl mutation timed out");
        if (exitCode !== 0) {
            root.conflictMessage = root.parseConflict(stderrText);
            return root.fail(root.conflictMessage.length ? root.conflictMessage
                             : "sleepyctl mutation failed with exit " + exitCode
                               + root.stderrDetail(stderrText));
        }
        try {
            const document = JSON.parse(stdoutText);
            if (!document || typeof document !== "object" || Array.isArray(document))
                throw new Error("expected JSON object");
            if (!root.applyDiagnosticSticky)
                root.diagnostic = "";
            root.mutationAccepted();
            return true;
        } catch (error) {
            return root.fail("sleepyctl mutation returned malformed output ("
                             + error.message + ")");
        }
    }

    function isApplyCommand(command) {
        return command && command.length > 0
            && command[command.length - 1] === "--apply";
    }

    function acceptApplyReport(command, document) {
        if (!root.exactKeys(document, ["status", "activePresetId"], [])
                || ["committed", "rolledBackConfirmed", "commitStateUnknown",
                    "reloadPending"].indexOf(document.status) < 0
                || !root.validString(document.activePresetId))
            throw new Error("apply report contract mismatch");
        if (document.status !== "committed") {
            root.refreshRequired = false;
            root.applyDiagnosticSticky = true;
            return root.fail("sleepyctl apply status " + document.status
                + "; keeping the last confirmed active preset");
        }
        if (command && command.length === 5
                && command[1] === "presets" && command[2] === "activate"
                && command[4] === "--apply"
                && document.activePresetId !== command[3])
            throw new Error("activation report target mismatch");
        root.activePresetId = document.activePresetId;
        root.refreshRequired = true;
        root.applyDiagnosticSticky = false;
        root.diagnostic = "";
        root.mutationAccepted();
        return true;
    }

    function acceptCommandResult(command, exitCode, stdoutText, stderrText, timedOut) {
        const duplicate = command && command.length === 5
            && command[1] === "presets" && command[2] === "duplicate";
        let duplicatePreset = null;
        if (duplicate && !timedOut && exitCode === 0) {
            try {
                const document = JSON.parse(stdoutText);
                if (!root.exactKeys(document, ["preset"], [])
                        || !root.validPreset(document.preset)
                        || document.preset.origin !== "user"
                        || document.preset.basePresetId !== command[3])
                    throw new Error("duplicate result contract mismatch");
                duplicatePreset = document.preset;
            } catch (error) {
                return root.fail("sleepyctl presets duplicate returned malformed output ("
                                 + error.message + ")");
            }
        }
        let accepted = false;
        if (root.isApplyCommand(command) && !timedOut && exitCode === 0) {
            root.busy = false;
            root.conflictMessage = "";
            root.conflictActions = Object.freeze([]);
            try {
                accepted = root.acceptApplyReport(command, JSON.parse(stdoutText));
            } catch (error) {
                return root.fail("sleepyctl apply returned malformed output ("
                                 + error.message + ")");
            }
        } else {
            accepted = root.acceptMutationResult(
                exitCode, stdoutText, stderrText, timedOut);
        }
        if (accepted && duplicatePreset) {
            const nextPresets = root.presets.slice();
            nextPresets.push(duplicatePreset);
            root.presets = Object.freeze(nextPresets);
            root.copyCreated(duplicatePreset.id);
        }
        return accepted;
    }

    function acceptExportResult(exitCode, stdoutText, stderrText, timedOut) {
        if (timedOut)
            return root.fail("sleepyctl presets export timed out");
        if (exitCode !== 0)
            return root.fail("sleepyctl presets export failed with exit " + exitCode
                             + root.stderrDetail(stderrText));
        try {
            const document = JSON.parse(stdoutText);
            if (!root.validPreset(document))
                throw new Error("export contract mismatch");
            root.lastExportJson = JSON.stringify(document, null, 2);
            root.busy = false;
            if (!root.applyDiagnosticSticky)
                root.diagnostic = "";
            root.exportReady(root.lastExportJson);
            return true;
        } catch (error) {
            return root.fail("sleepyctl presets export returned malformed output ("
                             + error.message + ")");
        }
    }

    function canEdit(preset) {
        return preset && preset.origin === "user";
    }

    function displayName(preset) {
        if (!preset)
            return "Unknown preset";
        return preset.name + " · " + preset.id.slice(0, 8);
    }
}
