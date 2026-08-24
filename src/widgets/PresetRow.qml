import QtQuick 6.0

FocusScope {
    id: root
    required property string presetId
    required property string label
    required property bool active
    required property bool editable
    required property var colors
    signal activated(string presetId)
    signal editRequested(string presetId)
    activeFocusOnTab: true
    implicitHeight: 54
    Keys.onReturnPressed: event => { root.activated(root.presetId); event.accepted = true; }
    Rectangle { anchors.fill: parent; radius: 14; color: root.active ? root.colors.accentSoft : root.colors.surfaceRaised; border.width: root.activeFocus ? 2 : 1; border.color: root.activeFocus ? root.colors.accent : root.colors.border }
    Column {
        anchors { left: parent.left; leftMargin: 12; right: parent.right; rightMargin: 54; verticalCenter: parent.verticalCenter }
        spacing: 1
        Text { text: root.label; color: root.colors.textPrimary; font.pixelSize: 11; font.weight: Font.DemiBold; elide: Text.ElideRight; width: parent.width }
        Text { text: root.editable ? "User preset" : "Built-in · Copy & edit keeps updates safe"; color: root.colors.textSecondary; font.pixelSize: 8 }
    }
    MouseArea { anchors.fill: parent; onClicked: root.activated(root.presetId) }
    Rectangle {
        z: 2
        anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
        width: 38; height: 28; radius: 9
        color: root.colors.surfaceQuiet
        border.width: 1; border.color: root.colors.border
        Text { anchors.centerIn: parent; text: root.editable ? "Edit" : "Copy"; color: root.colors.textSecondary; font.pixelSize: 8 }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.editRequested(root.presetId) }
    }
    Accessible.name: label
    Accessible.role: Accessible.RadioButton
    Accessible.checked: active
}
