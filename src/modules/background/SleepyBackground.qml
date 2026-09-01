// SPDX-License-Identifier: GPL-3.0-only
// Daemon-confirmed semantic background used until v3 exposes approved image handles.

import QtQuick 6.0

Rectangle {
    id: root
    objectName: "task10Background"

    required property var outputState
    required property var colors
    property bool reducedMotion: Boolean(root.outputState.reducedMotion)
    property bool opaque: Boolean(root.outputState.opaque)
    readonly property real outputScale: Number(root.outputState.monitor?.scale ?? 1)
    readonly property int motionDuration: root.reducedMotion ? 0 : 180
    readonly property color renderedColor: root.colors.background || "#17131f"
    readonly property string wallpaperId: String(root.outputState.currentWallpaperId || "")

    color: renderedColor
    Accessible.role: Accessible.Pane
    Accessible.name: wallpaperId.length ? "Desktop background" : "Desktop background unavailable"

    Behavior on color {
        ColorAnimation { duration: root.motionDuration }
    }
}
