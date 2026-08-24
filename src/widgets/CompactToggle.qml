import QtQuick 6.0

FocusScope {
    id: root
    required property string label
    required property string detail
    required property string iconName
    required property bool checked
    required property bool capabilityEnabled
    required property bool busy
    required property var iconRegistry
    required property var tokens
    required property var colors
    signal toggled(bool checked)

    activeFocusOnTab: capabilityEnabled && !busy
    implicitHeight: 74
    opacity: capabilityEnabled ? 1 : 0.58

    function invoke() {
        if (root.capabilityEnabled && !root.busy)
            root.toggled(!root.checked);
    }
    Keys.onReturnPressed: event => { root.invoke(); event.accepted = true; }
    Keys.onSpacePressed: event => { root.invoke(); event.accepted = true; }

    Rectangle {
        anchors.fill: parent
        radius: root.tokens.innerRadius
        color: root.checked ? root.colors.accentSoft : root.colors.surfaceRaised
        border.width: root.activeFocus ? 2 : 1
        border.color: root.activeFocus ? root.colors.accent : root.colors.border
    }
    SleepyIcon {
        anchors { left: parent.left; leftMargin: root.tokens.gridUnit; verticalCenter: parent.verticalCenter }
        iconRegistry: root.iconRegistry
        name: root.iconName
        iconColor: root.checked ? root.colors.accent : root.colors.textSecondary
        iconSize: 21
        accessibleName: ""
    }
    Column {
        anchors { left: parent.left; leftMargin: 46; right: switchTrack.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
        spacing: 2
        Text { text: root.label; color: root.colors.textPrimary; font.pixelSize: 12; font.weight: Font.DemiBold; elide: Text.ElideRight; width: parent.width }
        Text { text: root.capabilityEnabled ? root.detail : "Unsupported"; color: root.colors.textSecondary; font.pixelSize: 9; elide: Text.ElideRight; width: parent.width }
    }
    Rectangle {
        id: switchTrack
        anchors { right: parent.right; rightMargin: root.tokens.gridUnit; verticalCenter: parent.verticalCenter }
        width: 34; height: 20; radius: 10
        color: root.checked ? root.colors.accent : root.colors.surfaceQuiet
        Rectangle {
            width: 14; height: 14; radius: 7; y: 3
            x: root.checked ? parent.width - width - 3 : 3
            color: root.checked ? root.colors.shellBackground : root.colors.textSecondary
            Behavior on x { NumberAnimation { duration: root.tokens.motionDuration } }
        }
    }
    MouseArea { anchors.fill: parent; enabled: root.capabilityEnabled && !root.busy; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: root.invoke() }
    Accessible.name: label
    Accessible.description: detail
    Accessible.role: Accessible.CheckBox
    Accessible.checked: checked
}
