pragma ComponentBehavior: Bound

import QtQuick 6.0

Rectangle {
    id: root
    required property var media
    required property bool capabilityEnabled
    required property bool busy
    required property var iconRegistry
    required property var tokens
    required property var colors
    signal transportRequested(string transport)
    function focusControl(index) {
        if (!controlRepeater.count) return false;
        controlRepeater.itemAt(Math.max(0, Math.min(controlRepeater.count - 1, index)))
            .forceActiveFocus();
        return true;
    }
    implicitHeight: 96
    radius: tokens.innerRadius
    color: colors.surfaceRaised
    border.width: 1
    border.color: colors.border
    Column {
        anchors { left: parent.left; right: controls.left; top: parent.top; bottom: parent.bottom; margins: 13; rightMargin: 8 }
        spacing: 4
        Text { text: root.media ? root.media.title : "Nothing playing"; color: root.colors.textPrimary; font.pixelSize: 12; font.weight: Font.DemiBold; elide: Text.ElideRight; width: parent.width }
        Text { text: root.media && root.media.artist ? root.media.artist : "Media controls unavailable"; color: root.colors.textSecondary; font.pixelSize: 9; elide: Text.ElideRight; width: parent.width }
    }
    Row {
        id: controls
        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
        spacing: 5
        Repeater {
            id: controlRepeater
            model: [
                {name: "previous", icon: "icons.media-previous", label: "Previous"},
                {name: "playPause", icon: root.media && root.media.playing ? "icons.media-pause" : "icons.media-play", label: root.media && root.media.playing ? "Pause" : "Play"},
                {name: "next", icon: "icons.media-next", label: "Next"}
            ]
            delegate: IconButton {
                required property var modelData
                required property int index
                objectName: "mediaControl-" + modelData.name
                compact: true
                label: modelData.label
                iconName: modelData.icon
                iconRegistry: root.iconRegistry
                tokens: root.tokens
                colors: root.colors
                enabled: root.capabilityEnabled && !root.busy
                Keys.onLeftPressed: event => { root.focusControl(index - 1); event.accepted = true; }
                Keys.onRightPressed: event => { root.focusControl(index + 1); event.accepted = true; }
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Home) {
                        root.focusControl(0); event.accepted = true;
                    } else if (event.key === Qt.Key_End) {
                        root.focusControl(controlRepeater.count - 1); event.accepted = true;
                    }
                }
                onTriggered: root.transportRequested(modelData.name)
            }
        }
    }
}
