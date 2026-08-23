pragma ComponentBehavior: Bound

import QtQuick 6.0
import Quickshell

Scope {
    id: root

    required property var tokens
    required property var colors
    required property var artworkRegistry
    required property var surfaceController
    required property var workspaceService
    required property var clockService

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: railWindow

            required property var modelData

            screen: modelData
            implicitWidth: root.tokens.railWidth
            color: "transparent"
            exclusiveZone: root.tokens.railWidth + root.tokens.outerInset * 2
            aboveWindows: true

            anchors {
                top: true
                bottom: true
                left: true
            }
            margins.top: root.tokens.outerInset
            margins.bottom: root.tokens.outerInset
            margins.left: root.tokens.outerInset

            RailView {
                anchors.fill: parent
                tokens: root.tokens
                colors: root.colors
                artworkRegistry: root.artworkRegistry
                surfaceController: root.surfaceController
                workspaceModel: root.workspaceService.items
                timeText: root.clockService.railTime
                onWorkspaceActivated: index => root.workspaceService.focusWorkspace(index)
            }
        }
    }
}
