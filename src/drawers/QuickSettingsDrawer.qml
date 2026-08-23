pragma ComponentBehavior: Bound

import QtQuick 6.0
import Quickshell

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

            screen: modelData
            visible: root.surfaceController.isOpen("quickSettings")
            implicitWidth: root.tokens.drawerWidth
            color: "transparent"
            exclusiveZone: 0
            focusable: visible
            aboveWindows: true

            anchors {
                top: true
                bottom: true
                left: true
            }
            margins.top: root.tokens.outerInset
            margins.bottom: root.tokens.outerInset
            margins.left: root.tokens.outerInset + root.tokens.railWidth + root.tokens.drawerGap

            QuickSettingsView {
                id: drawerView

                width: parent.width
                height: parent.height
                x: root.surfaceController.isOpen("quickSettings") ? 0 : -root.tokens.gridUnit * 2
                surfaceController: root.surfaceController
                quickSettingsState: root.quickSettingsState
                tokens: root.tokens
                colors: root.colors
                diagnostic: root.sessionAdapter.diagnostic

                Behavior on x {
                    NumberAnimation {
                        duration: root.tokens.motionDuration
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Connections {
                target: root.surfaceController

                function onSurfaceOpened(id) {
                    if (id === "quickSettings")
                        Qt.callLater(drawerView.forceActiveFocus);
                }
            }
        }
    }
}
