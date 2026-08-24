pragma ComponentBehavior: Bound

import QtQuick 6.0
import Quickshell
import "../panels" as Panels
import "../services" as Services

Scope {
    id: root

    required property var tokens
    required property var colors
    required property var surfaceController
    required property var systemAdapter
    required property var presetAdapter
    required property var surfaceRegistry
    required property var iconRegistry
    required property var clockService
    required property var effects
    readonly property int transitionDuration: tokens.motionDuration

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: drawerWindow

            required property var modelData
            readonly property string screenKey: String(modelData.name)
            readonly property var descriptor:
                root.surfaceRegistry.descriptorFor("controlCenter")
            readonly property Panels.ShellGeometry geometry: Panels.ShellGeometry {
                viewportHeight: drawerWindow.modelData.height
                viewportWidth: drawerWindow.modelData.width
                inset: root.tokens.outerInset
                railWidth: root.tokens.railWidth
                gap: root.tokens.drawerGap
                drawerWidth: drawerWindow.descriptor
                    ? drawerWindow.descriptor.width : root.tokens.drawerWidth
                surfaceEdge: drawerWindow.descriptor
                    ? drawerWindow.descriptor.edge : "left"
            }
            readonly property Services.SurfaceWindowPolicy windowPolicy:
                Services.SurfaceWindowPolicy {
                    surfaceController: root.surfaceController
                    surfaceId: "controlCenter"
                    screenKey: drawerWindow.screenKey
                    descriptor: drawerWindow.descriptor
                }

            screen: modelData
            visible: windowPolicy.drawerVisible
            implicitWidth: geometry.drawerWidth
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            focusable: windowPolicy.drawerFocusable
            aboveWindows: true

            anchors {
                top: true
                bottom: true
                left: geometry.drawerAnchorLeft
                right: geometry.drawerAnchorRight
            }
            margins.top: geometry.drawerY
            margins.bottom: geometry.drawerY
            margins.left: geometry.drawerAnchorLeft ? geometry.drawerMarginLeft : 0
            margins.right: geometry.drawerAnchorRight ? geometry.drawerMarginRight : 0

            ControlCenterView {
                id: drawerView

                width: parent.width
                height: parent.height
                x: drawerWindow.windowPolicy.drawerVisible
                   ? 0 : (drawerWindow.geometry.drawerAnchorLeft ? -1 : 1)
                         * root.tokens.gridUnit * 2
                tokens: root.tokens
                colors: root.colors
                effects: root.effects
                iconRegistry: root.iconRegistry
                clockService: root.clockService
                systemAdapter: root.systemAdapter
                presetAdapter: root.presetAdapter
                surfaceController: root.surfaceController
                screenKey: drawerWindow.screenKey
                onCloseRequested: root.surfaceController.close("controlCenter", drawerWindow.screenKey)
                onSessionActionConfirmed: (action, confirmation) =>
                    root.systemAdapter.perform(action, confirmation)
                onSystemCommandRequested: (command, generation) => {
                    const capability = command[3];
                    const valueText = command[4];
                    let value = valueText;
                    if (valueText === "true" || valueText === "false") value = valueText === "true";
                    else if (!Number.isNaN(Number(valueText))) value = Number(valueText);
                    root.systemAdapter.mutate(capability, value);
                }
                onPresetCommandRequested: command => root.presetAdapter.run(command)

                Behavior on x {
                    NumberAnimation {
                        duration: root.transitionDuration
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Connections {
                target: root.surfaceController

                function onSurfaceOpened(id, screenKey) {
                    if (id === "controlCenter"
                            && screenKey === drawerWindow.screenKey)
                        Qt.callLater(drawerView.forceInitialFocus);
                }
            }
        }
    }
}
