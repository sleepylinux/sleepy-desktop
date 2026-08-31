// SPDX-License-Identifier: GPL-3.0-only

pragma ComponentBehavior: Bound

import QtQuick 6.0

Item {
    id: root

    required property var desktopModel
    required property var commandClient
    property bool reducedMotion: false
    readonly property int motionDuration: reducedMotion ? 0 : 180
    readonly property int outputCount: outputs.count

    function outputAt(index) { return outputs.itemAt(index); }

    Repeater {
        id: outputs
        model: root.desktopModel.monitors
        delegate: CoreOutputSurface {
            required property int index
            required property var modelData
            x: index * width
            width: root.width / Math.max(1, outputs.count)
            height: root.height
            desktopModel: root.desktopModel
            commandClient: root.commandClient
            monitor: modelData
            motionDuration: root.motionDuration
        }
    }
}
