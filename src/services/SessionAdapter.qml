// SPDX-License-Identifier: GPL-3.0-only
// Modified for Sleepy on 2026-08-31: settings facade without local process authority.

import QtQuick 6.0
import "SettingsCodec.js" as SettingsCodec
import "DesktopCommands.js" as DesktopCommands

SessionAdapterCore {
    id: root

    property bool loadOnStartup: true

    function refresh() {
        root.settings = SettingsCodec.defaultSettings();
        root.available = DesktopModel.available;
        root.busy = false;
        root.diagnostic = DesktopModel.available
            ? "" : "Desktop session settings are unavailable; using immutable defaults";
        if (root.available)
            root.settingsAccepted();
        return root.available;
    }

    function activatePreset(presetId) {
        if (typeof presetId !== "string" || presetId.trim().length === 0)
            return false;
        root.busy = true;
        const command = DesktopCommands.appearanceApplyTheme(presetId);
        const sent = command ? CommandClient.appearance(command) : false;
        root.busy = false;
        return sent;
    }

    Component.onCompleted: if (root.loadOnStartup) Qt.callLater(root.refresh)

    readonly property Connections desktopConnections: Connections {
        target: DesktopModel
        function onAvailableChanged() { root.refresh(); }
    }
}
