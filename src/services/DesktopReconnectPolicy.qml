// SPDX-License-Identifier: GPL-3.0-only
// Modified for Sleepy on 2026-08-31: instantiable clean-disconnect reconnect policy.

import QtQuick 6.0

QtObject {
    id: root

    property bool enabled: true
    property int minimumRetryMs: 250
    property int maximumRetryMs: 10000
    property int reconnectAttempt: 0
    property bool intentionalDisconnect: false

    signal disconnected(string message)
    signal reconnectDue

    function boundedRetryDelay(attempt) {
        const floor = Math.max(1, root.minimumRetryMs);
        const ceiling = Math.max(floor, root.maximumRetryMs);
        const raw = floor * Math.pow(2, Math.max(0, attempt));
        return Math.min(ceiling, raw);
    }

    function stop(message) {
        root.intentionalDisconnect = true;
        reconnectTimer.stop();
        root.disconnected(message || "Desktop stream stopped");
        root.intentionalDisconnect = false;
        return true;
    }

    function scheduleReconnect(message, countAttempt) {
        root.disconnected(message);
        if (!root.enabled)
            return false;
        const attemptForDelay = root.reconnectAttempt;
        if (countAttempt && !reconnectTimer.running)
            root.reconnectAttempt = Math.min(16, root.reconnectAttempt + 1);
        if (!reconnectTimer.running)
            reconnectTimer.interval = root.boundedRetryDelay(attemptForDelay);
        reconnectTimer.restart();
        return true;
    }

    function handleSocketDisconnected(message) {
        if (root.intentionalDisconnect || !root.enabled)
            return false;
        return root.scheduleReconnect(message || "Desktop stream disconnected", true);
    }

    readonly property Timer reconnectTimer: Timer {
        interval: root.minimumRetryMs
        repeat: false
        onTriggered: root.reconnectDue()
    }
}
