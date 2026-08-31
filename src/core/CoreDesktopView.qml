// SPDX-License-Identifier: GPL-3.0-only

pragma ComponentBehavior: Bound

import QtQuick 6.0
import QtQml.Models 2.15

Item {
    id: root

    required property var desktopModel
    required property var commandClient
    property bool reducedMotion: false
    readonly property int motionDuration: reducedMotion ? 0 : 180
    readonly property int outputCount: outputs.count

    function outputAt(index) { return outputs.itemAt(index); }

    function modelIndex(outputId) {
        for (let index = outputIds.count - 1; index >= 0; --index) {
            if (outputIds.get(index).monitorKey === outputId)
                return index;
        }
        return -1;
    }

    function reconcileOutputs() {
        const desired = root.desktopModel.monitors.map(monitor => String(monitor.id));
        for (let index = outputIds.count - 1; index >= 0; --index) {
            if (desired.indexOf(outputIds.get(index).monitorKey) < 0)
                outputIds.remove(index);
        }
        for (let target = 0; target < desired.length; ++target) {
            const outputId = desired[target];
            const current = root.modelIndex(outputId);
            if (current < 0)
                outputIds.insert(target, {"monitorKey": outputId});
            else if (current !== target)
                outputIds.move(current, target, 1);
        }
    }

    ListModel { id: outputIds }

    Connections {
        target: root.desktopModel
        function onMonitorsChanged() { root.reconcileOutputs(); }
    }

    Component.onCompleted: root.reconcileOutputs()

    Repeater {
        id: outputs
        model: outputIds
        delegate: CoreOutputSurface {
            required property int index
            required property string monitorKey
            readonly property var monitorRow: root.desktopModel.monitors.find(
                candidate => String(candidate.id) === monitorKey) || null
            x: index * width
            width: root.width / Math.max(1, outputs.count)
            height: root.height
            desktopModel: root.desktopModel
            commandClient: root.commandClient
            monitor: monitorRow
            motionDuration: root.motionDuration
        }
    }
}
