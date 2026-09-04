// SPDX-License-Identifier: GPL-3.0-only
// Sleepy compatibility IPC names mapped onto the modular shell graph.

import QtQuick 6.0
import Quickshell
import Quickshell.Io
import "DesktopCommands.js" as DesktopCommands
import qs.modules.nexus

Scope {
    id: root

    function activeState(): var {
        return ShellState.forActive();
    }

    function setDrawer(name: string, open: bool): bool {
        const state = root.activeState();
        if (!state || typeof state[name] !== "boolean")
            return false;
        state[name] = open;
        return true;
    }

    function toggleDrawer(name: string): bool {
        const state = root.activeState();
        return state ? root.setDrawer(name, !state[name]) : false;
    }

    function closeDrawers(): bool {
        const state = root.activeState();
        if (!state)
            return false;
        for (const name of ["launcher", "dashboard", "sidebar", "session", "utilities"])
            state[name] = false;
        return true;
    }

    function sessionAction(action: string): bool {
        const command = DesktopCommands.session(action);
        return command ? CommandClient.session(command) : false;
    }

    function media(transport: string): bool {
        const player = Players.active;
        if (!player)
            return false;
        if (transport === "playPause")
            player.togglePlaying();
        else if (transport === "next")
            player.next();
        else if (transport === "previous")
            player.previous();
        else
            return false;
        return true;
    }

    IpcHandler {
        target: "sleepy"

        function toggleControlCenter(): void { root.toggleDrawer("dashboard"); }
        function openControlCenter(): void { root.setDrawer("dashboard", true); }
        function closeActiveSurface(): void { root.closeDrawers(); }
        function requestSessionAction(action: string): void { root.sessionAction(action); }

        function toggleLauncher(): void { root.toggleDrawer("launcher"); }
        function toggleNotifications(): void { root.toggleDrawer("sidebar"); }
        function toggleDashboard(): void { root.toggleDrawer("dashboard"); }
        function toggleNexus(): void { WindowFactory.create(); }
        function closeOverlay(): void { root.closeDrawers(); }
        function mediaPlayPause(): void { root.media("playPause"); }
        function mediaNext(): void { root.media("next"); }
        function mediaPrevious(): void { root.media("previous"); }
        function lock(): void { root.sessionAction("lock"); }
        function openPowerMenu(): void { root.setDrawer("session", true); }
    }
}
