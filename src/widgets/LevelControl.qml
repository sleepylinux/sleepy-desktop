import QtQuick 6.0

FocusScope {
    id: root
    required property string label
    required property string iconName
    required property real value
    required property bool capabilityEnabled
    required property bool busy
    required property var iconRegistry
    required property var tokens
    required property var colors
    property string detail: Math.round(value * 100) + "%"
    signal valueRequested(real value)

    activeFocusOnTab: capabilityEnabled && !busy
    implicitHeight: 58
    opacity: capabilityEnabled ? 1 : 0.58

    function request(candidate) {
        if (!root.capabilityEnabled || root.busy || !Number.isFinite(candidate)) return;
        root.valueRequested(Math.max(0, Math.min(1, candidate)));
    }
    Keys.onLeftPressed: event => { root.request(root.value - 0.05); event.accepted = true; }
    Keys.onRightPressed: event => { root.request(root.value + 0.05); event.accepted = true; }

    SleepyIcon {
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        iconRegistry: root.iconRegistry; name: root.iconName; iconColor: root.colors.textSecondary; iconSize: 18; accessibleName: ""
    }
    Text {
        anchors { left: parent.left; leftMargin: 28; top: parent.top; topMargin: 6 }
        text: root.label; color: root.colors.textPrimary; font.pixelSize: 11; font.weight: Font.DemiBold
    }
    Text {
        anchors { right: parent.right; top: parent.top; topMargin: 6 }
        text: root.capabilityEnabled ? root.detail : "Unsupported"; color: root.colors.textSecondary; font.pixelSize: 10
    }
    Rectangle {
        id: track
        anchors { left: parent.left; leftMargin: 28; right: parent.right; bottom: parent.bottom; bottomMargin: 9 }
        height: 6; radius: 3; color: root.colors.surfaceQuiet
        Rectangle { width: Math.max(0, Math.min(parent.width, parent.width * root.value)); height: parent.height; radius: 3; color: root.colors.accent }
        MouseArea {
            anchors.fill: parent; enabled: root.capabilityEnabled && !root.busy
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onPressed: mouse => root.request(mouse.x / width)
        }
    }
    Rectangle { anchors.fill: parent; color: "transparent"; radius: root.tokens.innerRadius; border.width: root.activeFocus ? 2 : 0; border.color: root.colors.accent }
    Accessible.name: label
    Accessible.description: detail
    Accessible.role: Accessible.Slider
}
