// SPDX-License-Identifier: GPL-3.0-only

pragma ComponentBehavior: Bound

import QtQuick 6.0
import Quickshell

Scope {
    id: root

    required property var desktopModel
    required property var commandClient
    required property var tokens
    property var screens: Quickshell.screens
    property Component barWindowComponent: productionBarWindow
    property Component osdWindowComponent: productionOsdWindow
    property var outputModels: []
    property var outputModelCache: []
    property int nextOutputSerial: 1
    readonly property int outputCount: outputVariants.instances.length

    function outputAt(index) {
        return index >= 0 && index < outputVariants.instances.length
            ? outputVariants.instances[index] : null;
    }

    function reconcileOutputs() {
        const desired = root.desktopModel.monitors;
        const previous = root.outputModels.slice();
        const next = [];
        for (const monitor of desired) {
            const outputId = String(monitor.id);
            const retained = previous.find(model => model.id === outputId)
                || root.outputModelCache.find(model => model.id === outputId);
            if (retained) {
                retained.name = String(monitor.name);
                next.push(retained);
            } else {
                const created = outputModelFactory.createObject(root, {
                    "id": outputId,
                    "name": String(monitor.name)
                });
                root.outputModelCache = root.outputModelCache.concat([created]);
                next.push(created);
            }
        }
        const changed = previous.length !== next.length
            || previous.some((model, index) => model !== next[index]);
        if (!changed)
            return;
        root.outputModels = next;
    }

    Connections {
        target: root.desktopModel
        function onMonitorsChanged() { root.reconcileOutputs(); }
    }

    Component.onCompleted: root.reconcileOutputs()

    Component {
        id: outputModelFactory
        QtObject {
            required property string id
            required property string name
        }
    }

    Component {
        id: productionBarWindow
        PanelWindow {
            id: barWindow
            required property var shellScreen
            required property var outputState
            screen: shellScreen
            visible: shellScreen !== null && outputState.barVisible
            color: "transparent"
            aboveWindows: true
            focusable: visible
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: outputState.barVisible ? 64 : 0
            implicitWidth: !outputState.barVisible ? 0
                : outputState.expandedTrayItemId.length ? 248 : bar.implicitWidth
            anchors { left: true; top: true; bottom: true }
            margins.left: 12
            margins.top: 12
            margins.bottom: 12

            CoreBar {
                id: bar
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                outputState: barWindow.outputState
            }

            CoreTrayPopup {
                anchors {
                    left: bar.right
                    leftMargin: 10
                    bottom: parent.bottom
                    bottomMargin: 18
                }
                outputState: barWindow.outputState
            }
        }
    }

    Component {
        id: productionOsdWindow
        PanelWindow {
            id: osdWindow
            required property var shellScreen
            required property var outputState
            screen: shellScreen
            visible: shellScreen !== null && outputState.osdVisible
            color: "transparent"
            aboveWindows: true
            focusable: visible
            exclusionMode: ExclusionMode.Ignore
            implicitWidth: 280
            implicitHeight: 72
            anchors { bottom: true }
            margins.bottom: 36

            CoreOsd {
                anchors.fill: parent
                outputState: osdWindow.outputState
            }
        }
    }

    Variants {
        id: outputVariants
        model: root.outputModels

        delegate: Scope {
            required property var modelData
            id: outputScope
            readonly property string outputId: String(modelData.id)
            property int instanceSerial: 0
            readonly property var monitor: modelData
            readonly property string outputName: state.outputName
            readonly property var shellScreen: root.screens.find(
                candidate => String(candidate.name) === outputScope.outputName) || null
            property var barWindow: null
            property var osdWindow: null

            CoreOutputState {
                id: state
                desktopModel: root.desktopModel
                commandClient: root.commandClient
                monitor: outputScope.monitor
                motionDuration: root.tokens.motionDuration
            }

            Component.onCompleted: {
                outputScope.instanceSerial = root.nextOutputSerial;
                root.nextOutputSerial += 1;
                outputScope.barWindow = root.barWindowComponent.createObject(outputScope, {
                    "shellScreen": Qt.binding(function() { return outputScope.shellScreen; }),
                    "outputState": state
                });
                outputScope.osdWindow = root.osdWindowComponent.createObject(outputScope, {
                    "shellScreen": Qt.binding(function() { return outputScope.shellScreen; }),
                    "outputState": state
                });
            }
        }
    }
}
