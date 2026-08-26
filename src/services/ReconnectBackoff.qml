// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0

QtObject {
    id: root
    property int attempt: 0
    property int delayMs: 250

    function fail() {
        root.delayMs = Math.min(10000, 250 * Math.pow(2, root.attempt));
        root.attempt = Math.min(6, root.attempt + 1);
    }

    function succeed() {
        root.attempt = 0;
        root.delayMs = 250;
    }
}
