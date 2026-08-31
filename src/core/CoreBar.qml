// SPDX-License-Identifier: GPL-3.0-only
// Derived from Caelestia v2.4.0's clipped vertical-left workspace/tray composition.

pragma ComponentBehavior: Bound

import QtQuick 6.0
import QtQml.Models 2.15

Rectangle {
    id: root

    required property var outputState
    readonly property string edge: "left"
    property bool shown: root.outputState.barVisible

    clip: true
    visible: shown
    enabled: shown
    implicitWidth: root.shown ? 64 : 0
    implicitHeight: 720
    radius: 24
    color: root.outputState.colors.surface || "#202124"

    function workspaceIndex(workspaceId) {
        for (let index = 0; index < workspaceModel.count; ++index) {
            if (workspaceModel.get(index).workspaceId === workspaceId)
                return index;
        }
        return -1;
    }

    function reconcileWorkspaces() {
        const desired = root.outputState.workspaceRows.map(row => String(row.id));
        for (let index = workspaceModel.count - 1; index >= 0; --index) {
            if (desired.indexOf(workspaceModel.get(index).workspaceId) < 0)
                workspaceModel.remove(index);
        }
        for (let target = 0; target < desired.length; ++target) {
            const workspaceId = desired[target];
            const current = root.workspaceIndex(workspaceId);
            if (current < 0)
                workspaceModel.insert(target, {"workspaceId": workspaceId});
            else if (current !== target)
                workspaceModel.move(current, target, 1);
        }
    }

    ListModel { id: workspaceModel }

    Connections {
        target: root.outputState
        function onWorkspaceRowsChanged() { root.reconcileWorkspaces(); }
    }

    Component.onCompleted: root.reconcileWorkspaces()

    Behavior on implicitWidth {
        NumberAnimation {
            duration: root.outputState.motionDuration
            easing.type: Easing.OutCubic
        }
    }

    CoreOverlayTriggers {
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            topMargin: 12
        }
        outputState: root.outputState
    }

    Column {
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            topMargin: 160
        }
        spacing: 7

        Repeater {
            id: workspaceRepeater
            model: workspaceModel
            delegate: Rectangle {
                id: workspaceButton
                required property string workspaceId
                readonly property var modelData: root.outputState.workspaceRows.find(
                    workspace => String(workspace.id) === workspaceButton.workspaceId) || ({})
                readonly property bool focused: modelData.id === root.outputState.focusedWorkspaceId
                readonly property bool occupied:
                    root.outputState.occupiedWorkspaceIds.indexOf(modelData.id) >= 0
                readonly property bool special:
                    root.outputState.specialWorkspaceIds.indexOf(modelData.id) >= 0

                objectName: "workspace:" + modelData.id
                width: 42
                height: special ? 34 : 42
                enabled: root.outputState.barVisible
                activeFocusOnTab: enabled
                Accessible.role: Accessible.Button
                Accessible.name: "Workspace " + modelData.name
                Accessible.ignored: !enabled
                opacity: special ? 0.76 : 1
                signal clicked
                onClicked: root.outputState.focusWorkspace(modelData.id)
                Keys.onReturnPressed: workspaceButton.clicked()
                Keys.onSpacePressed: workspaceButton.clicked()
                Accessible.onPressAction: {
                    if (workspaceButton.enabled)
                        workspaceButton.clicked();
                }

                radius: height / 2
                color: workspaceButton.focused
                    ? (root.outputState.colors.accent || "#8ab4f8")
                    : workspaceButton.occupied ? "#3c4043" : "#262a2e"

                Behavior on color {
                    ColorAnimation { duration: root.outputState.motionDuration }
                }

                Text {
                    anchors.centerIn: parent
                    text: workspaceButton.modelData.name.replace(/^special:/, "")
                    color: workspaceButton.focused ? "#101418" : "#f1f3f4"
                    font.pixelSize: 12
                    font.bold: workspaceButton.focused
                }

                TapHandler { onTapped: workspaceButton.clicked() }
            }
        }
    }

    Column {
        anchors {
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
            bottomMargin: 18
        }
        spacing: 8

        CoreStatusStrip { outputState: root.outputState }
        CoreTray { outputState: root.outputState }
    }
}
