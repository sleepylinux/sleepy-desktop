// SPDX-License-Identifier: GPL-3.0-only
// Closed production IPC routing for the uniquely focused daemon-confirmed output.

import QtQuick 6.0

QtObject {
    id: root

    required property var outputStates

    function focusedOutput() {
        const focused = root.outputStates.filter(state =>
            state && state.monitor && Boolean(state.monitor.focused));
        return focused.length === 1 ? focused[0] : null;
    }

    function toggle(surface) {
        if (["launcher", "notifications", "dashboard", "nexus"].indexOf(surface) < 0)
            return false;
        const output = root.focusedOutput();
        return output ? output.toggleOverlay(surface) : false;
    }

    function close() {
        const output = root.focusedOutput();
        if (!output)
            return false;
        output.closeOverlay();
        return true;
    }

    function media(transport) {
        if (["playPause", "next", "previous"].indexOf(transport) < 0)
            return false;
        const output = root.focusedOutput();
        if (!output || !output.mediaAvailable)
            return false;
        const players = output.players || [];
        const player = players.find(candidate => Boolean(candidate.playing)) || players[0];
        return player ? output.controlPlayer(String(player.id), transport) : false;
    }

    function lock() {
        const output = root.focusedOutput();
        return output && output.sessionAvailable ? output.performSession("lock") : false;
    }

    function openPowerMenu() {
        const output = root.focusedOutput();
        if (!output || !output.sessionAvailable || !output.setNexusTab("session"))
            return false;
        return output.openOverlay("nexus");
    }
}
