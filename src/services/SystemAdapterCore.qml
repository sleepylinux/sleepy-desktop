import QtQuick 6.0

QtObject {
    id: root

    property string executable: "sleepyctl"
    property var snapshot: null
    property bool available: false
    readonly property bool busy: pendingCount > 0
    property string diagnostic: "System state has not been loaded"
    property int nextGeneration: 0
    property int lastAcceptedGeneration: 0
    property int lastCompletedGeneration: 0
    property bool refreshRequested: false
    property var pendingKinds: ({})
    property int pendingCount: 0
    property string mutationCapabilityBusy: ""
    property bool runtimeStreamRequired: false
    property bool runtimeStreamReady: true

    readonly property var capabilityKeys: [
        "network.enabled", "bluetooth.enabled", "audio.volume", "audio.muted",
        "audio.microphoneLevel", "audio.microphoneMuted", "audio.outputDevice",
        "display.brightness", "display.nightLightEnabled", "power.profile",
        "battery.status", "media.transport"
    ]
    readonly property var sessionActionKeys: ["lock", "logout", "reboot", "powerOff"]

    signal snapshotAccepted(int generation)
    signal diagnosticRaised(string message)
    signal immediateRefreshRequested

    function own(object, key) {
        return Object.prototype.hasOwnProperty.call(object, key);
    }

    function exactKeys(object, keys) {
        if (!object || typeof object !== "object" || Array.isArray(object))
            return false;
        const actual = Object.keys(object).sort();
        const expected = keys.slice().sort();
        return actual.length === expected.length
            && actual.every(function(value, index) { return value === expected[index]; });
    }

    function optional(value, validator) {
        return value === null || validator(value);
    }

    function normalized(value) {
        return typeof value === "number" && Number.isFinite(value)
            && value >= 0 && value <= 1;
    }

    function stringOrNull(value) {
        return value === null || typeof value === "string";
    }

    function validCapabilityState(value) {
        return ["available", "unavailable", "busy", "error"].indexOf(value) >= 0;
    }

    function validateCapabilityMap(map) {
        if (!map || typeof map !== "object" || Array.isArray(map))
            return false;
        const keys = Object.keys(map);
        return keys.length > 0 && keys.every(function(key) {
            return root.capabilityKeys.indexOf(key) >= 0 && root.validCapabilityState(map[key]);
        });
    }

    function validateDiagnostics(map) {
        if (!map || typeof map !== "object" || Array.isArray(map))
            return false;
        return Object.keys(map).every(function(key) {
            const item = map[key];
            return root.capabilityKeys.indexOf(key) >= 0
                && root.exactKeys(item, ["kind", "message"])
                && ["unsupported", "busy", "timeout", "parse", "command"].indexOf(item.kind) >= 0
                && typeof item.message === "string" && item.message.length > 0;
        });
    }

    function validateSessionActions(map) {
        return root.exactKeys(map, root.sessionActionKeys)
            && root.sessionActionKeys.every(function(key) {
                return root.validCapabilityState(map[key]);
            });
    }

    function validateNetwork(value) {
        return root.optional(value, function(item) {
            return root.exactKeys(item, ["enabled", "connectedName", "signalLevel"])
                && typeof item.enabled === "boolean"
                && root.stringOrNull(item.connectedName)
                && (item.signalLevel === null || root.normalized(item.signalLevel));
        });
    }

    function validateBluetooth(value) {
        return root.optional(value, function(item) {
            return root.exactKeys(item, ["enabled", "connectedDevice"])
                && typeof item.enabled === "boolean"
                && root.stringOrNull(item.connectedDevice);
        });
    }

    function validateAudio(value) {
        return root.optional(value, function(item) {
            if (!root.exactKeys(item, ["volume", "muted", "microphoneLevel",
                                     "microphoneMuted", "outputDeviceId", "outputDevices"])
                    || !root.normalized(item.volume) || typeof item.muted !== "boolean"
                    || !root.normalized(item.microphoneLevel)
                    || typeof item.microphoneMuted !== "boolean"
                    || !root.stringOrNull(item.outputDeviceId)
                    || !Array.isArray(item.outputDevices))
                return false;
            const ids = {};
            let defaults = 0;
            for (let i = 0; i < item.outputDevices.length; ++i) {
                const device = item.outputDevices[i];
                if (!root.exactKeys(device, ["id", "label", "isDefault"])
                        || typeof device.id !== "string" || device.id.length === 0
                        || typeof device.label !== "string" || device.label.length === 0
                        || typeof device.isDefault !== "boolean" || root.own(ids, device.id))
                    return false;
                ids[device.id] = true;
                if (device.isDefault) {
                    defaults += 1;
                    if (item.outputDeviceId !== device.id)
                        return false;
                }
            }
            return item.outputDevices.length === 0
                ? item.outputDeviceId === null : defaults === 1;
        });
    }

    function validateDisplay(value) {
        return root.optional(value, function(item) {
            return root.exactKeys(item, ["brightness", "nightLightEnabled"])
                && (item.brightness === null || root.normalized(item.brightness))
                && typeof item.nightLightEnabled === "boolean";
        });
    }

    function validatePower(value) {
        return root.optional(value, function(item) {
            if (!root.exactKeys(item, ["batteryLevel", "charging", "currentProfile",
                                     "availableProfiles"])
                    || (item.batteryLevel !== null && !root.normalized(item.batteryLevel))
                    || (item.charging !== null && typeof item.charging !== "boolean")
                    || !Array.isArray(item.availableProfiles))
                return false;
            const allowed = ["power-saver", "balanced", "performance"];
            if (item.currentProfile !== null && allowed.indexOf(item.currentProfile) < 0)
                return false;
            return item.availableProfiles.every(function(profile, index) {
                return allowed.indexOf(profile) >= 0
                    && item.availableProfiles.indexOf(profile) === index;
            }) && (item.currentProfile === null
                    ? item.availableProfiles.length === 0
                    : item.availableProfiles.indexOf(item.currentProfile) >= 0);
        });
    }

    function validateMedia(value) {
        return root.optional(value, function(item) {
            return root.exactKeys(item, ["title", "artist", "playing"])
                && typeof item.title === "string" && root.stringOrNull(item.artist)
                && typeof item.playing === "boolean";
        });
    }

    function validateSnapshot(document) {
        return root.exactKeys(document, ["schemaVersion", "generation", "capabilities",
                                        "diagnostics", "sessionActions", "network",
                                        "bluetooth", "audio", "display", "power", "media"])
            && document.schemaVersion === 1 && Number.isInteger(document.generation)
            && document.generation > 0 && root.validateCapabilityMap(document.capabilities)
            && root.validateDiagnostics(document.diagnostics)
            && root.validateSessionActions(document.sessionActions)
            && root.validateNetwork(document.network) && root.validateBluetooth(document.bluetooth)
            && root.validateAudio(document.audio) && root.validateDisplay(document.display)
            && root.validatePower(document.power) && root.validateMedia(document.media);
    }

    function allocate(kind) {
        root.nextGeneration += 1;
        const pending = Object.assign({}, root.pendingKinds);
        pending[root.nextGeneration] = kind;
        root.pendingKinds = pending;
        root.pendingCount += 1;
        root.refreshRequested = false;
        return root.nextGeneration;
    }

    function finish(requestGeneration) {
        if (!root.own(root.pendingKinds, requestGeneration))
            return;
        const pending = Object.assign({}, root.pendingKinds);
        if (pending[requestGeneration] === "mutation")
            root.mutationCapabilityBusy = "";
        delete pending[requestGeneration];
        root.pendingKinds = pending;
        root.pendingCount = Math.max(0, root.pendingCount - 1);
    }

    function beginSnapshot() {
        const generation = root.allocate("snapshot");
        return [root.executable, "system", "show", "--generation", String(generation)];
    }

    function mutationValueValid(capability, value) {
        if (["network.enabled", "bluetooth.enabled", "audio.muted",
             "audio.microphoneMuted", "display.nightLightEnabled"].indexOf(capability) >= 0)
            return typeof value === "boolean";
        if (["audio.volume", "audio.microphoneLevel", "display.brightness"].indexOf(capability) >= 0)
            return root.normalized(value);
        if (capability === "audio.outputDevice")
            return typeof value === "string" && value.length > 0;
        if (capability === "power.profile")
            return ["power-saver", "balanced", "performance"].indexOf(value) >= 0;
        if (capability === "media.transport")
            return ["playPause", "next", "previous"].indexOf(value) >= 0;
        return false;
    }

    function mutationConfirmed(mutation, snapshot) {
        if (!root.exactKeys(mutation, ["capability", "value"])
                || !root.mutationValueValid(mutation.capability, mutation.value)
                || !root.validateSnapshot(snapshot)
                || snapshot.capabilities[mutation.capability] !== "available")
            return false;
        switch (mutation.capability) {
        case "network.enabled":
            return snapshot.network !== null
                && snapshot.network.enabled === mutation.value;
        case "bluetooth.enabled":
            return snapshot.bluetooth !== null
                && snapshot.bluetooth.enabled === mutation.value;
        case "audio.volume":
            return snapshot.audio !== null && snapshot.audio.volume === mutation.value;
        case "audio.muted":
            return snapshot.audio !== null && snapshot.audio.muted === mutation.value;
        case "audio.microphoneLevel":
            return snapshot.audio !== null
                && snapshot.audio.microphoneLevel === mutation.value;
        case "audio.microphoneMuted":
            return snapshot.audio !== null
                && snapshot.audio.microphoneMuted === mutation.value;
        case "audio.outputDevice":
            return snapshot.audio !== null
                && snapshot.audio.outputDeviceId === mutation.value;
        case "display.brightness":
            return snapshot.display !== null
                && snapshot.display.brightness === mutation.value;
        case "display.nightLightEnabled":
            return snapshot.display !== null
                && snapshot.display.nightLightEnabled === mutation.value;
        case "power.profile":
            return snapshot.power !== null
                && snapshot.power.currentProfile === mutation.value;
        case "media.transport":
            return snapshot.media !== null;
        default:
            return false;
        }
    }

    function validDiagnostic(value) {
        return root.exactKeys(value, ["kind", "message"])
            && ["unsupported", "busy", "timeout", "parse", "command"]
                .indexOf(value.kind) >= 0
            && typeof value.message === "string" && value.message.trim().length > 0;
    }

    function beginMutation(capability, value) {
        if ((root.runtimeStreamRequired && !root.runtimeStreamReady)
                || !root.mutationValueValid(capability, value))
            return null;
        const generation = root.allocate("mutation");
        root.mutationCapabilityBusy = capability;
        return [root.executable, "system", "set", capability, String(value),
                "--generation", String(generation)];
    }

    function beginSessionAction(action, confirmation) {
        if (root.sessionActionKeys.indexOf(action) < 0 || confirmation !== "confirmed")
            return null;
        const generation = root.allocate("session");
        return [root.executable, "session", "perform", action, "confirmed",
                "--generation", String(generation)];
    }

    function fail(label, message) {
        root.diagnostic = label + " " + message;
        root.diagnosticRaised(root.diagnostic);
        return false;
    }

    function decodeResult(requestGeneration, exitCode, stdoutText, stderrText,
                          timedOut, label) {
        root.finish(requestGeneration);
        if (requestGeneration <= root.lastCompletedGeneration)
            return null;
        root.lastCompletedGeneration = requestGeneration;
        if (timedOut) {
            root.fail(label, "timed out");
            return null;
        }
        if (exitCode !== 0) {
            const detail = String(stderrText).trim();
            root.fail(label, "failed with exit " + exitCode
                      + (detail.length ? ": " + detail : ""));
            return null;
        }
        try {
            const document = JSON.parse(stdoutText);
            if (!document || document.generation !== requestGeneration)
                throw new Error("generation mismatch");
            return document;
        } catch (error) {
            root.fail(label, "returned malformed output (" + error.message + ")");
            return null;
        }
    }

    function commitSnapshot(document) {
        if (!root.validateSnapshot(document))
            return root.fail("sleepyctl system", "returned malformed output (contract mismatch)");
        root.snapshot = Object.freeze(document);
        root.lastAcceptedGeneration = document.generation;
        root.available = true;
        root.diagnostic = "";
        root.snapshotAccepted(document.generation);
        return true;
    }

    function acceptSnapshotResult(requestGeneration, exitCode, stdoutText, stderrText, timedOut) {
        const document = root.decodeResult(requestGeneration, exitCode, stdoutText,
                                           stderrText, timedOut, "sleepyctl system show");
        return document !== null && root.commitSnapshot(document);
    }

    function acceptMutationResult(requestGeneration, exitCode, stdoutText, stderrText, timedOut) {
        const document = root.decodeResult(requestGeneration, exitCode, stdoutText,
                                           stderrText, timedOut, "sleepyctl system set");
        if (!document || !root.exactKeys(document,
              ["schemaVersion", "generation", "mutation", "snapshot"])
                || document.schemaVersion !== 1
                || !document.mutation || !root.mutationConfirmed(
                    document.mutation, document.snapshot)
                || document.snapshot.generation !== document.generation)
            return document ? root.fail("sleepyctl system set", "returned malformed output") : false;
        if (!root.commitSnapshot(document.snapshot))
            return false;
        root.refreshRequested = true;
        root.immediateRefreshRequested();
        return true;
    }

    function acceptSessionResult(requestGeneration, exitCode, stdoutText, stderrText, timedOut) {
        const document = root.decodeResult(requestGeneration, exitCode, stdoutText,
                                           stderrText, timedOut, "sleepyctl session perform");
        if (!document || !root.exactKeys(document,
              ["schemaVersion", "generation", "action", "status", "diagnostic"])
                || document.schemaVersion !== 1
                || root.sessionActionKeys.indexOf(document.action) < 0
                || ["initiated", "failed"].indexOf(document.status) < 0
                || (document.status === "initiated" && document.diagnostic !== null)
                || (document.status === "failed"
                    && !root.validDiagnostic(document.diagnostic)))
            return document ? root.fail("sleepyctl session perform", "returned malformed output") : false;
        root.lastAcceptedGeneration = document.generation;
        root.diagnostic = document.status === "failed"
            ? document.diagnostic.message : "";
        return document.status === "initiated";
    }

    function capabilityState(capability) {
        if (root.runtimeStreamRequired && !root.runtimeStreamReady)
            return "unavailable";
        return root.snapshot && root.own(root.snapshot.capabilities, capability)
            ? root.snapshot.capabilities[capability] : "unavailable";
    }

    function isCapabilityBusy(capability) {
        return root.mutationCapabilityBusy === capability
            || root.capabilityState(capability) === "busy";
    }

    function sessionActionAvailable(action) {
        return root.snapshot && root.own(root.snapshot.sessionActions, action)
            && root.snapshot.sessionActions[action] === "available";
    }

    function runtimeValue(events, id) {
        const capability = events.capability(id);
        if (!capability.available || !capability.value) return null;
        return capability.value.data !== undefined ? capability.value.data : capability.value;
    }

    function runtimeState(events, id) {
        const capability = events.capability(id);
        if (capability.status === "available") return "available";
        return capability.status === "timeout" || capability.status === "parse"
             || capability.status === "error" ? "error" : "unavailable";
    }

    function acceptRuntimeEvents(events) {
        if (!events || !events.snapshotReceived) return false;
        const network = root.runtimeValue(events, "network");
        const bluetooth = root.runtimeValue(events, "bluetooth");
        const audio = root.runtimeValue(events, "audio");
        const brightness = root.runtimeValue(events, "brightness");
        const nightLight = root.runtimeValue(events, "nightLight");
        const battery = root.runtimeValue(events, "battery");
        const powerProfile = root.runtimeValue(events, "powerProfile");
        const media = root.runtimeValue(events, "media");
        const capabilities = {
            "network.enabled": root.runtimeState(events, "network"),
            "bluetooth.enabled": root.runtimeState(events, "bluetooth"),
            "audio.volume": root.runtimeState(events, "audio"),
            "audio.muted": root.runtimeState(events, "audio"),
            "audio.microphoneLevel": root.runtimeState(events, "audio"),
            "audio.microphoneMuted": root.runtimeState(events, "audio"),
            "audio.outputDevice": root.runtimeState(events, "audio"),
            "display.brightness": root.runtimeState(events, "brightness"),
            "display.nightLightEnabled": root.runtimeState(events, "nightLight"),
            "power.profile": root.runtimeState(events, "powerProfile"),
            "battery.status": root.runtimeState(events, "battery"),
            "media.transport": root.runtimeState(events, "media")
        };
        const diagnostics = {};
        Object.keys(capabilities).forEach(function(key) {
            if (capabilities[key] === "available") return;
            const domain = key.split(".")[0] === "display"
                         ? (key.indexOf("brightness") >= 0 ? "brightness" : "nightLight")
                         : key.split(".")[0] === "power" ? "powerProfile"
                         : key.split(".")[0] === "battery" ? "battery"
                         : key.split(".")[0] === "media" ? "media" : key.split(".")[0];
            const cap = events.capability(domain);
            diagnostics[key] = {"kind": cap.status === "timeout" ? "timeout"
                : cap.status === "parse" ? "parse" : "unsupported",
                "message": cap.diagnostic || cap.status};
        });
        const outputDevices = audio && audio.defaultOutputId ? [{"id": audio.defaultOutputId,
            "label": audio.defaultOutputId, "isDefault": true}] : [];
        const document = {
            "schemaVersion": 1, "generation": Math.max(1, Math.floor(events.generation)),
            "capabilities": capabilities, "diagnostics": diagnostics,
            "sessionActions": {"lock": "unavailable", "logout": "unavailable",
                               "reboot": "unavailable", "powerOff": "unavailable"},
            "network": network ? {"enabled": network.wifiEnabled,
                "connectedName": network.activeConnectionId || null, "signalLevel": null} : null,
            "bluetooth": bluetooth ? {"enabled": bluetooth.powered,
                "connectedDevice": bluetooth.connectedDeviceIds && bluetooth.connectedDeviceIds.length
                    ? bluetooth.connectedDeviceIds[0] : null} : null,
            "audio": audio ? {"volume": audio.outputLevel, "muted": audio.outputMuted,
                "microphoneLevel": audio.inputLevel, "microphoneMuted": audio.inputMuted,
                "outputDeviceId": audio.defaultOutputId || null, "outputDevices": outputDevices} : null,
            "display": brightness || nightLight ? {"brightness": brightness ? brightness.level : null,
                "nightLightEnabled": nightLight ? nightLight.enabled : false} : null,
            "power": battery || powerProfile ? {"batteryLevel": battery ? battery.percentage / 100 : null,
                "charging": battery ? battery.charging : null,
                "currentProfile": powerProfile ? powerProfile.active : null,
                "availableProfiles": powerProfile ? powerProfile.available : []} : null,
            "media": media ? {"title": media.title, "artist": media.artist || null,
                "playing": Boolean(media.playing)} : null
        };
        return root.commitSnapshot(document);
    }
}
