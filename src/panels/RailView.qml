pragma ComponentBehavior: Bound

import QtQuick 6.0
import "../services" as Services
import "../widgets" as Widgets

FocusScope {
    id: root

    required property var tokens
    required property var colors
    required property var artworkRegistry
    required property var iconRegistry
    required property var surfaceRegistry
    required property var surfaceController
    required property var workspaceModel
    required property var effects
    property string timeText: "22\n24"
    property string screenKey: "default"

    readonly property int workspaceCount: workspaceRepeater.count
    readonly property var controlCenterDescriptor:
        surfaceRegistry.descriptorFor("controlCenter")
        || surfaceRegistry.descriptorFor("quickSettings")
    readonly property string controlCenterId:
        controlCenterDescriptor ? controlCenterDescriptor.id : "quickSettings"
    readonly property int triggerCount: surfaceTriggerRepeater.count
    readonly property Services.SurfaceWindowPolicy windowPolicy:
        Services.SurfaceWindowPolicy {
            surfaceController: root.surfaceController
            surfaceId: root.controlCenterId
            screenKey: root.screenKey
            descriptor: root.controlCenterDescriptor
        }

    signal workspaceActivated(int index)

    implicitWidth: tokens.railWidth
    implicitHeight: 720

    Widgets.GlassSurface {
        anchors.fill: parent
        radius: root.tokens.shellRadius
        colors: root.colors
        effects: root.effects
    }

    Widgets.BrandMark {
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            topMargin: root.tokens.railBrandTopInset
        }
        artworkRegistry: root.artworkRegistry
    }

    Column {
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            topMargin: root.tokens.railWorkspaceTop
        }
        spacing: root.tokens.railWorkspaceSpacing

        Repeater {
            id: workspaceRepeater
            model: root.workspaceModel

            delegate: Widgets.WorkspaceButton {
                required property var modelData

                workspaceIndex: Number(modelData.index)
                workspaceName: String(modelData.name)
                active: Boolean(modelData.active)
                tokens: root.tokens
                colors: root.colors
                onActivated: index => root.workspaceActivated(index)
            }
        }
    }

    Column {
        anchors {
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
            bottomMargin: root.tokens.railBottomInset
        }
        spacing: root.tokens.railBottomSpacing

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.timeText
            color: root.colors.textSecondary
            horizontalAlignment: Text.AlignHCenter
            lineHeight: 0.85
            font.family: "Inter"
            font.pixelSize: 11
            font.weight: Font.Medium
            font.features: {"tnum": 1}
        }

        Repeater {
            id: surfaceTriggerRepeater
            model: root.surfaceRegistry.availableDescriptors()

            delegate: Widgets.StatusButton {
                id: surfaceButton

                required property var modelData
                objectName: modelData.id + "Button"
                active: triggerPolicy.drawerVisible
                tokens: root.tokens
                colors: root.colors
                iconRegistry: root.iconRegistry
                iconName: modelData.triggerIcon
                accessibleName: modelData.triggerLabel
                onTriggered: triggerPolicy.toggleFromRail()

                readonly property Services.SurfaceWindowPolicy triggerPolicy:
                    Services.SurfaceWindowPolicy {
                        surfaceController: root.surfaceController
                        surfaceId: surfaceButton.modelData.id
                        screenKey: root.screenKey
                        descriptor: surfaceButton.modelData
                    }

                Connections {
                    target: surfaceButton.triggerPolicy

                    function onFocusReturnRequested() {
                        Qt.callLater(surfaceButton.forceActiveFocus);
                    }
                }
                Connections {
                    target: root.surfaceController

                    function onFocusReturnRequested(id, screenKey) {
                        if (id === surfaceButton.modelData.id
                                && screenKey === root.screenKey)
                            Qt.callLater(surfaceButton.forceActiveFocus);
                    }
                }
            }
        }
    }
}
