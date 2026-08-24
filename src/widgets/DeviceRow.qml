import QtQuick 6.0

FocusScope {
    id: root
    required property string deviceId
    required property string label
    required property bool selected
    required property bool capabilityEnabled
    required property var colors
    signal selectedRequested(string deviceId)
    activeFocusOnTab: capabilityEnabled
    implicitHeight: 42
    Keys.onReturnPressed: event => { if (root.capabilityEnabled) root.selectedRequested(root.deviceId); event.accepted = true; }
    Rectangle { anchors.fill: parent; radius: 12; color: root.selected ? root.colors.accentSoft : root.colors.surfaceQuiet; border.width: root.activeFocus ? 2 : 1; border.color: root.activeFocus ? root.colors.accent : root.colors.border }
    Text {
        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
        text: root.label; color: root.colors.textPrimary; font.pixelSize: 11
    }
    Text {
        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
        text: root.selected ? "Default" : ""; color: root.colors.accent; font.pixelSize: 9
    }
    MouseArea { anchors.fill: parent; enabled: root.capabilityEnabled; onClicked: root.selectedRequested(root.deviceId) }
    Accessible.name: label
    Accessible.role: Accessible.RadioButton
    Accessible.checked: selected
}
