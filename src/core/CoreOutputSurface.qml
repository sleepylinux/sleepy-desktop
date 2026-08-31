// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0

Item {
    id: root

    required property var desktopModel
    required property var commandClient
    required property var monitor
    property int motionDuration: 180

    readonly property alias outputId: state.outputId
    readonly property alias outputName: state.outputName
    readonly property alias workspaceIds: state.workspaceIds
    readonly property alias focusedWorkspaceId: state.focusedWorkspaceId
    readonly property alias occupiedWorkspaceIds: state.occupiedWorkspaceIds
    readonly property alias specialWorkspaceIds: state.specialWorkspaceIds
    readonly property alias barVisible: state.barVisible
    readonly property alias trayItems: state.trayItems
    readonly property alias trayActivationSupported: state.trayActivationSupported
    readonly property alias menuActivationSupported: state.menuActivationSupported
    readonly property alias trayExpandedItemId: state.expandedTrayItemId
    readonly property alias osdVisible: state.osdVisible
    readonly property alias osdKind: state.osdKind
    readonly property alias osdLevel: state.osdLevel
    readonly property alias osdMuted: state.osdMuted
    readonly property alias volumeControlAvailable: state.volumeControlAvailable
    readonly property alias muteControlAvailable: state.muteControlAvailable
    readonly property alias microphoneControlAvailable: state.microphoneControlAvailable
    readonly property alias brightnessControlAvailable: state.brightnessControlAvailable
    readonly property alias networkStatusAvailable: state.networkStatusAvailable
    readonly property alias bluetoothStatusAvailable: state.bluetoothStatusAvailable
    readonly property alias audioStatusAvailable: state.audioStatusAvailable
    readonly property alias batteryStatusAvailable: state.batteryStatusAvailable
    readonly property alias clockStatusAvailable: state.clockStatusAvailable
    readonly property alias networkStatusText: state.networkStatusText
    readonly property alias bluetoothStatusText: state.bluetoothStatusText
    readonly property alias audioStatusText: state.audioStatusText
    readonly property alias batteryStatusText: state.batteryStatusText
    readonly property alias clockStatusText: state.clockStatusText
    readonly property string barEdge: bar.edge
    readonly property bool barClips: bar.clip
    readonly property string osdPlacement: osd.placement
    readonly property bool osdClips: osd.clip
    readonly property bool trayPopupVisible: trayPopup.visible
    readonly property bool trayPopupOpen:
        state.expandedTrayItemId.length > 0 && state.barVisible

    function focusWorkspace(workspaceId) { return state.focusWorkspace(workspaceId); }
    function activateTrayItem(itemId) { return state.activateTrayItem(itemId); }
    function activateMenuNode(itemId, menuId) { return state.activateMenuNode(itemId, menuId); }
    function setOsdLevel(level) { return state.setOsdLevel(level); }
    function toggleOsdMuted() { return state.toggleOsdMuted(); }
    function setBrightness(level) { return state.setBrightness(level); }

    CoreOutputState {
        id: state
        desktopModel: root.desktopModel
        commandClient: root.commandClient
        monitor: root.monitor
        motionDuration: root.motionDuration
    }

    CoreBar {
        id: bar
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
            margins: 12
        }
        outputState: state
    }

    CoreOsd {
        id: osd
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: 36
        }
        outputState: state
    }

    CoreTrayPopup {
        id: trayPopup
        anchors {
            left: bar.right
            leftMargin: 10
            bottom: parent.bottom
            bottomMargin: 18
        }
        outputState: state
    }
}
