// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0

Rectangle {
    id: root

    required property string label
    property string description: root.enabled ? root.label : root.label + ", unavailable"
    property bool selected: false
    property color accent: "#8ab4f8"
    property color foreground: "#f1f3f4"
    signal triggered

    implicitWidth: Math.max(74, labelText.implicitWidth + 24)
    implicitHeight: 38
    radius: 12
    color: root.selected ? root.accent
        : root.activeFocus ? "#3c4043" : "#2a2e33"
    opacity: root.enabled ? 1 : 0.48
    // Hidden ancestors are omitted from Qt's tab chain automatically.  Keep
    // the control's own focus contract tied only to whether the daemon-backed
    // action is enabled so it remains inspectable and deterministic in tests.
    activeFocusOnTab: root.enabled
    Accessible.role: Accessible.Button
    Accessible.name: root.label
    Accessible.description: root.description
    Accessible.onPressAction: {
        if (root.enabled)
            root.triggered();
    }

    Keys.onReturnPressed: event => {
        if (root.enabled)
            root.triggered();
        event.accepted = true;
    }
    Keys.onEnterPressed: event => {
        if (root.enabled)
            root.triggered();
        event.accepted = true;
    }
    Keys.onSpacePressed: event => {
        if (root.enabled)
            root.triggered();
        event.accepted = true;
    }

    Text {
        id: labelText
        anchors.centerIn: parent
        width: parent.width - 16
        text: root.label
        textFormat: Text.PlainText
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        color: root.selected ? "#101418" : root.foreground
        font.pixelSize: 12
        font.bold: root.selected
    }

    TapHandler {
        enabled: root.enabled
        onTapped: root.triggered()
    }
}
