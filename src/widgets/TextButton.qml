import QtQuick 6.0

FocusScope {
    id: root
    required property string label
    required property var colors
    property bool destructive: false
    property bool emphasized: false
    property Item tabTarget: null
    property Item backtabTarget: null
    signal triggered
    activeFocusOnTab: enabled
    implicitWidth: Math.max(72, text.implicitWidth + 24)
    implicitHeight: 34
    opacity: enabled ? 1 : 0.45
    Keys.onReturnPressed: event => { if (root.enabled) root.triggered(); event.accepted = true; }
    Keys.onSpacePressed: event => { if (root.enabled) root.triggered(); event.accepted = true; }
    Keys.onTabPressed: event => {
        if (root.tabTarget) {
            root.tabTarget.forceActiveFocus(); event.accepted = true;
        } else event.accepted = false;
    }
    Keys.onBacktabPressed: event => {
        if (root.backtabTarget) {
            root.backtabTarget.forceActiveFocus(); event.accepted = true;
        } else event.accepted = false;
    }
    Rectangle {
        anchors.fill: parent; radius: 11
        color: root.emphasized ? root.colors.accentSoft : root.colors.surfaceRaised
        border.width: root.activeFocus ? 2 : 1
        border.color: root.destructive ? root.colors.error : root.activeFocus ? root.colors.accent : root.colors.border
    }
    Text { id: text; anchors.centerIn: parent; text: root.label; color: root.destructive ? root.colors.error : root.emphasized ? root.colors.accent : root.colors.textPrimary; font.pixelSize: 9; font.weight: Font.DemiBold }
    MouseArea { anchors.fill: parent; enabled: root.enabled; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: root.triggered() }
    Accessible.name: label
    Accessible.role: Accessible.Button
}
