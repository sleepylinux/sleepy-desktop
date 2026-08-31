// SPDX-License-Identifier: GPL-3.0-only
// Modified for Sleepy on 2026-08-31: preset UI facade without local process authority.

import QtQuick 6.0

PresetAdapterCore {
    id: root

    property bool loadOnStartup: true
    signal commandRejected(string reason)

    function refresh() {
        root.busy = false;
        root.available = DesktopModel.available;
        if (!root.available) {
            root.diagnostic = "Desktop preset state is unavailable";
            return false;
        }
        return true;
    }

    function run(_command) {
        root.busy = false;
        root.commandRejected("Preset mutations are delegated to sleepy-sessiond");
        return false;
    }

    function activate(id) {
        if (typeof id !== "string" || id.length === 0)
            return false;
        return CommandClient.appearance({
            "type": "applyTheme",
            "data": {"themeId": id}
        });
    }

    function duplicate(source, name) { return root.run(root.duplicateCommand(source, name)); }
    function rename(id, name) { return root.run(root.renameCommand(id, name)); }
    function remove(id) { return root.run(root.deleteCommand(id)); }
    function setBinding(id, action, accelerator, apply) {
        return root.run(root.setBindingCommand(id, action, accelerator, apply));
    }
    function importPreset(path, mode) { return root.run(root.importCommand(path, mode, true)); }

    Component.onCompleted: if (root.loadOnStartup) Qt.callLater(root.refresh)
}
