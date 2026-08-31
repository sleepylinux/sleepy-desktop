// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0

Item {
    id: root

    required property var desktopModel
    required property var commandClient
    required property var tokens
    readonly property int outputCount: view.outputCount

    function outputAt(index) { return view.outputAt(index); }

    CoreDesktopView {
        id: view
        anchors.fill: parent
        desktopModel: root.desktopModel
        commandClient: root.commandClient
        reducedMotion: root.tokens.motionDuration === 0
    }
}
