import QtQuick 6.0
import "../services" as Services
import "../widgets" as Widgets

FocusScope {
    id: root

    required property var surfaceController
    required property var quickSettingsState
    required property var tokens
    required property var colors
    property string diagnostic: ""
    property string screenKey: "default"

    readonly property Services.SurfaceWindowPolicy windowPolicy:
        Services.SurfaceWindowPolicy {
            surfaceController: root.surfaceController
            surfaceId: "quickSettings"
            screenKey: root.screenKey
        }

    implicitWidth: tokens.drawerWidth
    implicitHeight: 720
    visible: windowPolicy.drawerVisible
    opacity: visible ? 1 : 0
    focus: visible

    Keys.onEscapePressed: event => {
        root.surfaceController.close("quickSettings", root.screenKey);
        event.accepted = true;
    }

    Behavior on opacity {
        NumberAnimation {
            duration: root.tokens.motionDuration
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.tokens.shellRadius
        color: root.colors.surface
        border.width: 1
        border.color: root.colors.border
    }

    Column {
        anchors {
            fill: parent
            margins: root.tokens.contentPadding
        }
        spacing: root.tokens.gridUnit

        Item {
            width: parent.width
            height: root.tokens.drawerHeaderHeight

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Text {
                    text: "Quick settings"
                    color: root.colors.textPrimary
                    font.family: "Inter"
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                    font.letterSpacing: -0.3
                }

                Text {
                    text: "Sunday evening · Sleepy"
                    color: root.colors.textSecondary
                    font.family: "Inter"
                    font.pixelSize: 11
                }
            }

            FocusScope {
                id: closeButton
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                width: root.tokens.drawerCloseSize
                height: root.tokens.drawerCloseSize
                activeFocusOnTab: true

                Rectangle {
                    anchors.fill: parent
                    radius: 13
                    color: closeButton.activeFocus ? root.colors.accentSoft : root.colors.surfaceRaised
                    border.width: 1
                    border.color: closeButton.activeFocus ? root.colors.accent : root.colors.border
                }
                Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: root.colors.textSecondary
                    font.pixelSize: 21
                }
                Keys.onReturnPressed:
                    root.surfaceController.close("quickSettings", root.screenKey)
                Keys.onSpacePressed:
                    root.surfaceController.close("quickSettings", root.screenKey)
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked:
                        root.surfaceController.close("quickSettings", root.screenKey)
                }
            }
        }

        Text {
            text: "CONNECTIONS & MODES"
            color: root.colors.textSecondary
            font.family: "Inter"
            font.pixelSize: 10
            font.weight: Font.DemiBold
            font.letterSpacing: 1.1
        }

        Grid {
            width: parent.width
            columns: 2
            columnSpacing: root.tokens.gridUnit
            rowSpacing: root.tokens.gridUnit

            Widgets.ControlTile {
                id: networkTile
                objectName: "networkTile"
                width: (parent.width - root.tokens.gridUnit) / 2
                label: "Network"
                detail: root.quickSettingsState.networkEnabled ? "Connected" : "Offline"
                iconText: "⌁"
                active: root.quickSettingsState.networkEnabled
                capabilityEnabled: root.quickSettingsState.supports("network")
                tokens: root.tokens
                colors: root.colors
                KeyNavigation.down: nightLightTile
                onTriggered: root.quickSettingsState.toggleFeature("network")
            }

            Widgets.ControlTile {
                id: bluetoothTile
                width: (parent.width - root.tokens.gridUnit) / 2
                label: "Bluetooth"
                detail: root.quickSettingsState.bluetoothEnabled ? "On" : "Off"
                iconText: "ᛒ"
                active: root.quickSettingsState.bluetoothEnabled
                capabilityEnabled: root.quickSettingsState.supports("bluetooth")
                tokens: root.tokens
                colors: root.colors
                KeyNavigation.down: focusTile
                onTriggered: root.quickSettingsState.toggleFeature("bluetooth")
            }

            Widgets.ControlTile {
                id: nightLightTile
                width: (parent.width - root.tokens.gridUnit) / 2
                label: "Night light"
                detail: root.quickSettingsState.nightLightEnabled ? "Warm" : "Neutral"
                iconText: "☾"
                active: root.quickSettingsState.nightLightEnabled
                capabilityEnabled: root.quickSettingsState.supports("nightLight")
                tokens: root.tokens
                colors: root.colors
                KeyNavigation.up: networkTile
                KeyNavigation.down: volumeRow
                onTriggered: root.quickSettingsState.toggleFeature("nightLight")
            }

            Widgets.ControlTile {
                id: focusTile
                width: (parent.width - root.tokens.gridUnit) / 2
                label: "Focus"
                detail: root.quickSettingsState.focusEnabled ? "Quiet" : "Available"
                iconText: "◌"
                active: root.quickSettingsState.focusEnabled
                capabilityEnabled: root.quickSettingsState.supports("focus")
                tokens: root.tokens
                colors: root.colors
                KeyNavigation.up: bluetoothTile
                KeyNavigation.down: volumeRow
                onTriggered: root.quickSettingsState.toggleFeature("focus")
            }
        }

        Text {
            text: "COMFORT"
            color: root.colors.textSecondary
            font.family: "Inter"
            font.pixelSize: 10
            font.weight: Font.DemiBold
            font.letterSpacing: 1.1
        }

        Widgets.SliderRow {
            id: volumeRow
            width: parent.width
            label: "Volume"
            iconText: "♪"
            value: root.quickSettingsState.volume
            capabilityEnabled: root.quickSettingsState.supports("volume")
            tokens: root.tokens
            colors: root.colors
            KeyNavigation.up: nightLightTile
            KeyNavigation.down: brightnessRow
            onValueRequested: value => root.quickSettingsState.setLevel("volume", value)
        }

        Widgets.SliderRow {
            id: brightnessRow
            width: parent.width
            label: "Brightness"
            iconText: "☼"
            value: root.quickSettingsState.brightness
            capabilityEnabled: root.quickSettingsState.supports("brightness")
            tokens: root.tokens
            colors: root.colors
            KeyNavigation.up: volumeRow
            onValueRequested: value => root.quickSettingsState.setLevel("brightness", value)
        }

        Item {
            width: parent.width
            height: root.tokens.drawerSectionSpacer
        }

        Rectangle {
            width: parent.width
            height: root.tokens.drawerDiagnosticHeight
            radius: root.tokens.innerRadius
            color: root.colors.surfaceQuiet
            visible: root.diagnostic.length > 0

            Text {
                anchors {
                    fill: parent
                    margins: root.tokens.gridUnit
                }
                text: root.diagnostic
                color: root.colors.warning
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.Wrap
                maximumLineCount: 2
                font.family: "Inter"
                font.pixelSize: 10
            }
        }
    }
}
