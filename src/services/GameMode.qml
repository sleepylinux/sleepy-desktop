// SPDX-License-Identifier: GPL-3.0-only
// Modified for Sleepy on 2026-08-31: game mode policy is daemon-owned.

pragma Singleton

import QtQuick
import Quickshell
import "DesktopCommands.js" as DesktopCommands

Singleton {
    id: root

    readonly property var gameModeCapability: DesktopModel.capabilityData(
        "utilities", "gameMode", {"enabled": false})
    property bool enabled: Boolean(gameModeCapability.enabled)
    property bool syncing: false

    function syncFromModel(): void {
        const next = Boolean(root.gameModeCapability.enabled);
        if (root.enabled === next)
            return;
        root.syncing = true;
        root.enabled = next;
        root.syncing = false;
    }

    function setEnabled(value: bool): bool {
        return CommandClient.utility(DesktopCommands.utilitySetGameMode(value));
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

    onGameModeCapabilityChanged: syncFromModel()
    onEnabledChanged: if (!root.syncing) {
        const desired = root.enabled;
        root.syncFromModel();
        root.setEnabled(desired);
    }
}
