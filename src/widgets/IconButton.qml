import QtQuick 6.0

FocusScope {
    id: root
    required property string label
    required property string iconName
    required property var iconRegistry
    required property var tokens
    required property var colors
    property bool destructive: false
    property bool compact: false
    property Item tabTarget: null
    property Item rightTarget: null
    property Item leftTarget: null
    signal triggered

    activeFocusOnTab: enabled
    implicitWidth: compact ? 38 : 44
    implicitHeight: implicitWidth
    opacity: enabled ? 1 : 0.48

    Keys.onReturnPressed: event => { if (root.enabled) root.triggered(); event.accepted = true; }
    Keys.onSpacePressed: event => { if (root.enabled) root.triggered(); event.accepted = true; }
    Keys.onTabPressed: event => {
        if (root.tabTarget && root.tabTarget.enabled) {
            root.tabTarget.forceActiveFocus();
            event.accepted = true;
        } else {
            event.accepted = false;
        }
    }
    Keys.onRightPressed: event => {
        if (root.rightTarget && root.rightTarget.enabled) {
            root.rightTarget.forceActiveFocus(); event.accepted = true;
        } else event.accepted = false;
    }
    Keys.onLeftPressed: event => {
        if (root.leftTarget && root.leftTarget.enabled) {
            root.leftTarget.forceActiveFocus(); event.accepted = true;
        } else event.accepted = false;
    }

    Rectangle {
        anchors.fill: parent
        radius: root.compact ? 12 : 14
        color: root.activeFocus ? root.colors.accentSoft : root.colors.surfaceRaised
        border.width: root.activeFocus ? 2 : 1
        border.color: root.destructive ? root.colors.error
                                      : root.activeFocus ? root.colors.accent : root.colors.border
    }
    SleepyIcon {
        anchors.centerIn: parent
        iconRegistry: root.iconRegistry
        name: root.iconName
        iconColor: root.destructive ? root.colors.error : root.colors.textSecondary
        iconSize: root.compact ? 17 : 19
        accessibleName: root.label
    }
    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.triggered()
    }
    Accessible.name: label
    Accessible.description: enabled ? label : label + ", unavailable"
    Accessible.role: Accessible.Button
}
