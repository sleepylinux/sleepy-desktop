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
    required property var quickSettingsState
    required property var sessionAdapter

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: drawerWindow

            required property var modelData
            readonly property string screenKey: String(modelData.name)
            readonly property Panels.ShellGeometry geometry: Panels.ShellGeometry {
                viewportHeight: drawerWindow.modelData.height
                inset: root.tokens.outerInset
                railWidth: root.tokens.railWidth
                gap: root.tokens.drawerGap
                drawerWidth: root.tokens.drawerWidth
            }
            readonly property Services.SurfaceWindowPolicy windowPolicy:
                Services.SurfaceWindowPolicy {
                    surfaceController: root.surfaceController
                    surfaceId: "quickSettings"
                    screenKey: drawerWindow.screenKey
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
                left: true
            }
            margins.top: geometry.drawerY
            margins.bottom: geometry.drawerY
            margins.left: geometry.drawerMarginLeft

            QuickSettingsView {
                id: drawerView

                width: parent.width
                height: parent.height
                x: drawerWindow.windowPolicy.drawerVisible
                   ? 0 : -root.tokens.gridUnit * 2
                surfaceController: root.surfaceController
                quickSettingsState: root.quickSettingsState
                tokens: root.tokens
                colors: root.colors
                diagnostic: root.sessionAdapter.diagnostic
                screenKey: drawerWindow.screenKey

                Behavior on x {
                    NumberAnimation {
                        duration: root.tokens.motionDuration
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Connections {
                target: root.surfaceController

                function onSurfaceOpened(id, screenKey) {
                    if (id === "quickSettings"
                            && screenKey === drawerWindow.screenKey)
                        Qt.callLater(drawerView.forceActiveFocus);
                }
            }
        }
    }
}
