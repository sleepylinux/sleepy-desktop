import QtQuick 6.0

QtObject {
    id: root
    readonly property var knownActions: Object.freeze([
        "app.terminal.open", "launcher.open", "window.close",
        "window.focus.left", "window.focus.right", "window.focus.up",
        "window.focus.down", "workspace.previous", "workspace.next",
        "surface.controlCenter.toggle", "session.lock", "session.logout",
        "session.reboot", "session.powerOff", "session.power",
        "media.playPause", "media.next", "media.previous",
        "audio.volume.up", "audio.volume.down", "audio.volume.toggleMute",
        "audio.microphone.toggleMute", "display.brightness.up",
        "display.brightness.down"
    ])
    readonly property var actions: Object.freeze({
        "surface.controlCenter.toggle": {"kind": "surface", "method": "toggleControlCenter"},
        "session.lock": {"kind": "session", "action": "lock", "confirmation": false},
        "session.logout": {"kind": "session", "action": "logout", "confirmation": true},
        "session.reboot": {"kind": "session", "action": "reboot", "confirmation": true},
        "session.powerOff": {"kind": "session", "action": "powerOff", "confirmation": true},
        "session.power": {"kind": "surface", "method": "openPowerMenu"}
    })
    function descriptor(action) {
        return typeof action === "string"
            && Object.prototype.hasOwnProperty.call(root.actions, action)
            ? root.actions[action] : null;
    }
}
