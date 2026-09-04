// SPDX-License-Identifier: GPL-3.0-only
// Modified for Sleepy on 2026-08-31: idle inhibition state is daemon-owned.

pragma Singleton

import QtQuick
import Quickshell
import "DesktopCommands.js" as DesktopCommands

Singleton {
    id: root

    readonly property var idleCapability: DesktopModel.capabilityData(
        "utilities", "idleInhibitor", {"enabled": false, "enabledSince": ""})
    property bool enabled: Boolean(idleCapability.enabled)
    readonly property date enabledSince: {
        const parsed = Date.parse(root.idleCapability.enabledSince || "");
        return Number.isNaN(parsed) ? new Date() : new Date(parsed);
    }
    property bool syncing: false

    function syncFromModel(): void {
        const next = Boolean(root.idleCapability.enabled);
        if (root.enabled === next)
            return;
        root.syncing = true;
        root.enabled = next;
        root.syncing = false;
    }

    function setEnabled(value: bool): bool {
        return CommandClient.utility(DesktopCommands.utilitySetIdleInhibited(value));
    }

    function toggle(): bool {
        return root.setEnabled(!root.enabled);
    }

    function enable(): bool {
        return root.setEnabled(true);
    }

    function disable(): bool {
        return root.setEnabled(false);
    }

    function isEnabled(): bool {
        return root.enabled;
    }

    onIdleCapabilityChanged: syncFromModel()
    onEnabledChanged: if (!root.syncing) {
        const desired = root.enabled;
        root.syncFromModel();
        root.setEnabled(desired);
    }
}
