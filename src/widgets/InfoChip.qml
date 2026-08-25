import QtQuick 6.0

Rectangle {
    id: root
    required property string label
    required property string value
    required property var colors
    implicitWidth: content.implicitWidth + 20
    implicitHeight: 28
    radius: 10
    color: colors.surfaceQuiet
    border.width: 1
    border.color: colors.border
    Row {
        id: content; anchors.centerIn: parent; spacing: 5
        Text { text: root.label; color: root.colors.textSecondary; font.pixelSize: 9 }
        Text { text: root.value; color: root.colors.textPrimary; font.pixelSize: 9; font.weight: Font.DemiBold }
    }
    Accessible.name: label + ": " + value
    Accessible.role: Accessible.StaticText
}
