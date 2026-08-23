.pragma library

var expectedKeys = [
    "activePresetId",
    "appearanceMode",
    "effectsProfile",
    "paletteSource",
    "panelVisibility",
    "reducedMotion",
    "schemaVersion",
    "webSearchEnabled"
];

function frozenCopy(document) {
    return Object.freeze({
        schemaVersion: document.schemaVersion,
        activePresetId: document.activePresetId,
        appearanceMode: document.appearanceMode,
        paletteSource: document.paletteSource,
        reducedMotion: document.reducedMotion,
        effectsProfile: document.effectsProfile,
        panelVisibility: document.panelVisibility,
        webSearchEnabled: document.webSearchEnabled
    });
}

function defaultSettings() {
    return frozenCopy({
        schemaVersion: 1,
        activePresetId: "builtin.sleepy",
        appearanceMode: "dark",
        paletteSource: "sleepy",
        reducedMotion: false,
        effectsProfile: "full",
        panelVisibility: "always",
        webSearchEnabled: true
    });
}

function includes(list, value) {
    return list.indexOf(value) !== -1;
}

function parseSettings(payload) {
    var document;
    try {
        document = JSON.parse(payload);
    } catch (error) {
        throw new Error("malformed JSON");
    }

    if (document === null || typeof document !== "object" || Array.isArray(document))
        throw new Error("settings output must be an object");

    var keys = Object.keys(document).sort();
    for (var index = 0; index < keys.length; index++) {
        if (!includes(expectedKeys, keys[index]))
            throw new Error("unknown key: " + keys[index]);
    }
    for (var expectedIndex = 0; expectedIndex < expectedKeys.length; expectedIndex++) {
        if (!Object.prototype.hasOwnProperty.call(document, expectedKeys[expectedIndex]))
            throw new Error("missing key: " + expectedKeys[expectedIndex]);
    }

    if (document.schemaVersion !== 1)
        throw new Error("unsupported schemaVersion");
    if (typeof document.activePresetId !== "string" || document.activePresetId.length === 0)
        throw new Error("activePresetId must be a non-empty string");
    if (!includes(["dark", "light", "system"], document.appearanceMode))
        throw new Error("invalid appearanceMode");
    if (!includes(["sleepy", "system", "custom"], document.paletteSource))
        throw new Error("invalid paletteSource");
    if (typeof document.reducedMotion !== "boolean")
        throw new Error("reducedMotion must be a boolean");
    if (!includes(["full", "reduced", "none"], document.effectsProfile))
        throw new Error("invalid effectsProfile");
    if (!includes(["always", "autoHide", "hidden"], document.panelVisibility))
        throw new Error("invalid panelVisibility");
    if (typeof document.webSearchEnabled !== "boolean")
        throw new Error("webSearchEnabled must be a boolean");

    return frozenCopy(document);
}
