import QtQuick 6.0

FocusScope {
    id: root
    required property string action
    required property string accelerator
    required property var colors
    property string conflict: ""
    signal editRequested(string action, string accelerator)
    activeFocusOnTab: true
    implicitHeight: conflict.length ? 66 : 50
    Keys.onReturnPressed: event => { root.editRequested(root.action, root.accelerator); event.accepted = true; }
    Rectangle { anchors.fill: parent; radius: 13; color: root.colors.surfaceRaised; border.width: root.activeFocus ? 2 : 1; border.color: root.conflict.length ? root.colors.error : root.activeFocus ? root.colors.accent : root.colors.border }
    Column {
        anchors { left: parent.left; right: parent.right; margins: 11; verticalCenter: parent.verticalCenter }
        spacing: 3
        Row { width: parent.width
            Text { width: parent.width * 0.62; text: root.action; color: root.colors.textPrimary; font.pixelSize: 10; elide: Text.ElideRight }
            Text { width: parent.width * 0.38; text: root.accelerator || "Unbound"; color: root.accelerator ? root.colors.accent : root.colors.textSecondary; horizontalAlignment: Text.AlignRight; font.pixelSize: 10; font.family: "monospace" }
        }
        Text { visible: root.conflict.length > 0; text: root.conflict; color: root.colors.error; font.pixelSize: 8; elide: Text.ElideRight; width: parent.width }
    }
    MouseArea { anchors.fill: parent; onClicked: root.editRequested(root.action, root.accelerator) }
    Accessible.name: action + ", " + (accelerator || "unbound")
    Accessible.role: Accessible.Button
}
