pragma ComponentBehavior: Bound

import QtQuick 6.0
import Quickshell
import "../services" as Services

Scope {
    id: root

    required property var tokens
    required property var colors
    required property var artworkRegistry
    required property var iconRegistry
    required property var surfaceRegistry
    required property var surfaceController
    required property var workspaceService
    required property var clockService
    required property var effects

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: railWindow

            required property var modelData
            readonly property string screenKey: String(modelData.name)
            readonly property ShellGeometry geometry: ShellGeometry {
                viewportHeight: railWindow.modelData.height
                viewportWidth: railWindow.modelData.width
                inset: root.tokens.outerInset
                railWidth: root.tokens.railWidth
                gap: root.tokens.drawerGap
                drawerWidth: root.tokens.drawerWidth
            }
            readonly property Services.SurfaceWindowPolicy windowPolicy:
                Services.SurfaceWindowPolicy {
                    surfaceController: root.surfaceController
                    surfaceId: "controlCenter"
                    screenKey: railWindow.screenKey
                    descriptor: root.surfaceRegistry.descriptorFor("controlCenter")
                }

            screen: modelData
            implicitWidth: geometry.railWidth
            color: "transparent"
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: geometry.railExclusiveZone
            focusable: windowPolicy.railFocusable
            aboveWindows: true

            anchors {
                top: true
                bottom: true
                left: true
            }
            margins.top: geometry.railY
            margins.bottom: geometry.railY
            margins.left: geometry.railMarginLeft

            RailView {
                anchors.fill: parent
                tokens: root.tokens
                colors: root.colors
                artworkRegistry: root.artworkRegistry
                iconRegistry: root.iconRegistry
                surfaceRegistry: root.surfaceRegistry
                surfaceController: root.surfaceController
                workspaceModel: root.workspaceService.items
                timeText: root.clockService.railTime
                screenKey: railWindow.screenKey
                effects: root.effects
                onWorkspaceActivated: index => root.workspaceService.focusWorkspace(index)
            }
        }
    }
}
