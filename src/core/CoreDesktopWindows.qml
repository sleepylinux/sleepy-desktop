// SPDX-License-Identifier: GPL-3.0-only

pragma ComponentBehavior: Bound

import QtQuick 6.0
import Quickshell

Scope {
    id: root

    required property var desktopModel
    required property var commandClient
    required property var tokens

    Variants {
        model: root.desktopModel.monitors

        delegate: Scope {
            id: outputScope
            required property var modelData
            readonly property var shellScreen: Quickshell.screens.find(
                candidate => String(candidate.name) === state.outputName) || null

            CoreOutputState {
                id: state
                desktopModel: root.desktopModel
                commandClient: root.commandClient
                monitor: outputScope.modelData
                motionDuration: root.tokens.motionDuration
            }

            PanelWindow {
                screen: outputScope.shellScreen
                visible: outputScope.shellScreen !== null
                color: "transparent"
                aboveWindows: true
                focusable: true
                exclusionMode: ExclusionMode.Normal
                exclusiveZone: state.barVisible ? 64 : 0
                implicitWidth: !state.barVisible ? 0
                    : state.expandedTrayItemId.length ? 248 : bar.implicitWidth
                anchors { left: true; top: true; bottom: true }
                margins.left: 12
                margins.top: 12
                margins.bottom: 12

                CoreBar {
                    id: bar
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    outputState: state
                }

                CoreTrayPopup {
                    anchors {
                        left: bar.right
                        leftMargin: 10
                        bottom: parent.bottom
                        bottomMargin: 18
                    }
                    outputState: state
                }
            }

            PanelWindow {
                screen: outputScope.shellScreen
                visible: outputScope.shellScreen !== null && state.osdVisible
                color: "transparent"
                aboveWindows: true
                focusable: true
                exclusionMode: ExclusionMode.Ignore
                implicitWidth: 280
                implicitHeight: 72
                anchors { bottom: true }
                margins.bottom: 36

                CoreOsd {
                    anchors.fill: parent
                    outputState: state
                }
            }
        }
    }
}
