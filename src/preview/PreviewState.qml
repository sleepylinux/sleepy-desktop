import QtQuick 6.0

QtObject {
    id: root

    property string appearanceMode: "dark"
    property string effectsProfile: "full"
    property bool reducedMotion: false
    property string scene: "main"

    signal previewChanged

    function setAppearanceMode(mode) {
        if (["dark", "light", "system"].indexOf(mode) === -1)
            return false;
        root.appearanceMode = mode;
        root.previewChanged();
        return true;
    }

    function setEffectsProfile(profile) {
        if (["full", "reduced", "none"].indexOf(profile) === -1)
            return false;
        root.effectsProfile = profile;
        root.previewChanged();
        return true;
    }

    function setReducedMotion(enabled) {
        root.reducedMotion = Boolean(enabled);
        root.previewChanged();
        return true;
    }

    function setScene(scene) {
        if (["main", "compact", "presets", "conflict", "confirmation"].indexOf(scene) < 0)
            return false;
        root.scene = scene;
        root.previewChanged();
        return true;
    }
}
