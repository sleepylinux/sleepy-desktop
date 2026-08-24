import QtQuick 6.0

QtObject {
    id: root

    property string artworkRoot: "@sleepyArtworkRoot@"
    property string manifestSource: "@sleepyArtworkManifest@"

    readonly property var assets: Object.freeze({
        "branding.primaryMark": "branding/logo.svg",
        "icons.control-center": "icons/control-center.svg",
        "icons.network": "icons/network.svg",
        "icons.bluetooth": "icons/bluetooth.svg",
        "icons.volume": "icons/volume.svg",
        "icons.microphone": "icons/microphone.svg",
        "icons.brightness": "icons/brightness.svg",
        "icons.night-light": "icons/night-light.svg",
        "icons.focus": "icons/focus.svg",
        "icons.battery": "icons/battery.svg",
        "icons.power-profile": "icons/power-profile.svg",
        "icons.media-play": "icons/media-play.svg",
        "icons.media-pause": "icons/media-pause.svg",
        "icons.media-next": "icons/media-next.svg",
        "icons.media-previous": "icons/media-previous.svg",
        "icons.lock": "icons/lock.svg",
        "icons.logout": "icons/logout.svg",
        "icons.power": "icons/power.svg",
        "icons.preset": "icons/preset.svg",
        "icons.keybinding": "icons/keybinding.svg"
    })
    readonly property int assetCount: Object.keys(assets).length

    function sourceFor(logicalName) {
        if (typeof logicalName !== "string"
                || !Object.prototype.hasOwnProperty.call(root.assets, logicalName))
            return "";

        const relativePath = root.assets[logicalName];
        if (relativePath.startsWith("/") || relativePath.includes(".."))
            return "";

        const base = root.artworkRoot.endsWith("/")
                   ? root.artworkRoot.slice(0, -1) : root.artworkRoot;
        return base + "/" + relativePath;
    }
}
