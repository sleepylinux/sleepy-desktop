// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0

QtObject {
    id: root
    property bool pending: false
    property bool dirty: false
    property int timeoutInterval: 2500
    signal timedOut
    signal retryRequested

    function begin() {
        if (root.pending) return false;
        root.pending = true;
        deadline.restart();
        return true;
    }
    function markDirty() {
        if (root.pending) root.dirty = true;
        else root.retryRequested();
    }
    function finish() {
        deadline.stop();
        root.pending = false;
        if (root.dirty) {
            root.dirty = false;
            root.retryRequested();
        }
    }
    readonly property Timer deadline: Timer {
        interval: root.timeoutInterval
        onTriggered: { root.pending = false; root.timedOut(); }
    }
}
