import QtQuick 6.0

FocusScope {
    id: root
    required property string deviceId
    required property string label
    required property bool selected
    required property bool capabilityEnabled
    required property bool busy
    required property var colors
    signal selectedRequested(string deviceId)
    signal navigationRequested(string direction)
    activeFocusOnTab: capabilityEnabled && !busy
    implicitHeight: 42
    opacity: capabilityEnabled ? busy ? 0.68 : 1 : 0.5
    function invoke() {
        if (!root.capabilityEnabled || root.busy) return false;
        root.selectedRequested(root.deviceId); return true;
    }
    Keys.onReturnPressed: event => { root.invoke(); event.accepted = true; }
    Keys.onSpacePressed: event => { root.invoke(); event.accepted = true; }
    Keys.onUpPressed: event => { root.navigationRequested("up"); event.accepted = true; }
    Keys.onDownPressed: event => { root.navigationRequested("down"); event.accepted = true; }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Home) {
            root.navigationRequested("home"); event.accepted = true;
        } else if (event.key === Qt.Key_End) {
            root.navigationRequested("end"); event.accepted = true;
        }
    }
    Rectangle { anchors.fill: parent; radius: 12; color: root.selected ? root.colors.accentSoft : root.colors.surfaceQuiet; border.width: root.activeFocus ? 2 : 1; border.color: root.activeFocus ? root.colors.accent : root.colors.border }
    Text {
        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
        text: root.label; color: root.colors.textPrimary; font.pixelSize: 11
    }
    Text {
        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
        text: root.busy ? "Switching…" : root.selected ? "Default" : ""; color: root.colors.accent; font.pixelSize: 9
    }
    MouseArea { anchors.fill: parent; enabled: root.capabilityEnabled && !root.busy; onClicked: root.invoke() }
    Accessible.name: label
    Accessible.description: !capabilityEnabled ? label + ", unavailable"
                            : busy ? label + ", busy, switching output"
                            : selected ? label + ", default output" : label
    Accessible.role: Accessible.RadioButton
    Accessible.checked: selected
}
