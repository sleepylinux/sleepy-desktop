import QtQuick 6.0
import QtQuick.Window 6.0
import "../drawers" as Drawers
import "../panels" as Panels
import "../services" as Services
import "../theme" as Theme
import "." as Preview

Window {
    id: root

    width: 1180
    height: 780
    minimumWidth: 980
    minimumHeight: 680
    visible: true
    title: "Sleepy settings preview"
    color: colors.shellBackground

    Preview.PreviewState { id: previewState }
    Theme.ThemeTokens {
        id: tokens
        reducedMotion: previewState.reducedMotion
    }
    Theme.Palette {
        id: colors
        appearanceMode: previewState.appearanceMode
    }
    Theme.EffectsPolicy {
        id: effects
        effectsProfile: previewState.effectsProfile
        reducedMotion: previewState.reducedMotion
    }
    Services.SurfaceRegistry {
        id: surfaceRegistry
        Component.onCompleted: registerDescriptor({
            "id": "controlCenter", "edge": "left", "width": tokens.drawerWidth,
            "triggerIcon": "icons.control-center", "triggerLabel": "Control center",
            "availability": true, "initialFocusKey": "network"
        })
    }
    Services.SurfaceController {
        id: surfaces
        surfaceRegistry: surfaceRegistry
        Component.onCompleted: {
            open("controlCenter");
        }
    }
    Services.QuickSettingsState { id: quickSettings }
    Services.ArtworkRegistry {
        id: artwork
        primaryMarkSource: "@sleepyPrimaryMark@"
    }
    Services.IconRegistry { id: icons }

    Rectangle {
        anchors.fill: parent
        color: colors.shellBackground
    }

    Row {
        id: header
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 30
        }
        spacing: tokens.gridUnit

        Column {
            width: 330
            spacing: 4

            Text {
                text: "Sleepy, your way"
                color: colors.textPrimary
                font.family: "Inter"
                font.pixelSize: 25
                font.weight: Font.DemiBold
            }
            Text {
                text: "Preview only — nothing is written to your session."
                color: colors.textSecondary
                font.family: "Inter"
                font.pixelSize: 11
            }
        }

        Row {
            spacing: 8
            anchors.verticalCenter: parent.verticalCenter

            Preview.PreviewChoice {
                label: "Dark"
                selected: previewState.appearanceMode === "dark"
                tokens: tokens
                colors: colors
                onTriggered: previewState.setAppearanceMode("dark")
            }
            Preview.PreviewChoice {
                label: "Light"
                selected: previewState.appearanceMode === "light"
                tokens: tokens
                colors: colors
                onTriggered: previewState.setAppearanceMode("light")
            }
            Preview.PreviewChoice {
                label: "Full effects"
                selected: previewState.effectsProfile === "full"
                tokens: tokens
                colors: colors
                onTriggered: previewState.setEffectsProfile("full")
            }
            Preview.PreviewChoice {
                label: "Reduced"
                selected: previewState.effectsProfile === "reduced"
                tokens: tokens
                colors: colors
                onTriggered: previewState.setEffectsProfile("reduced")
            }
            Preview.PreviewChoice {
                label: "No effects"
                selected: previewState.effectsProfile === "none"
                tokens: tokens
                colors: colors
                onTriggered: previewState.setEffectsProfile("none")
            }
            Preview.PreviewChoice {
                label: "Reduced motion"
                selected: previewState.reducedMotion
                tokens: tokens
                colors: colors
                onTriggered: previewState.setReducedMotion(!previewState.reducedMotion)
            }
        }
    }

    Item {
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            topMargin: 24
            leftMargin: 30
            rightMargin: 30
            bottomMargin: 30
        }

        Panels.RailView {
            id: previewRail
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
            }
            width: tokens.railWidth
            tokens: tokens
            colors: colors
            artworkRegistry: artwork
            iconRegistry: icons
            surfaceRegistry: surfaceRegistry
            surfaceController: surfaces
            effects: effects
            workspaceModel: [
                {"index": 1, "name": "web", "active": false},
                {"index": 2, "name": "work", "active": true},
                {"index": 3, "name": "chat", "active": false},
                {"index": 4, "name": "music", "active": false}
            ]
            timeText: "22\n24"
        }

        Drawers.QuickSettingsView {
            id: previewDrawer
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: previewRail.right
                leftMargin: tokens.drawerGap
            }
            width: tokens.drawerWidth
            surfaceController: surfaces
            quickSettingsState: quickSettings
            tokens: tokens
            colors: colors
            effects: effects
            iconRegistry: icons
            surfaceId: "controlCenter"
        }

        Rectangle {
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: previewDrawer.right
                right: parent.right
                leftMargin: tokens.contentPadding
            }
            radius: tokens.shellRadius
            color: colors.surface
            border.width: 1
            border.color: colors.border

            Column {
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: tokens.contentPadding
                }
                spacing: tokens.gridUnit

                Text {
                    text: "A calmer desktop"
                    color: colors.textPrimary
                    font.family: "Inter"
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                }
                Text {
                    width: parent.width
                    text: "The inset rail stays close without hugging the screen edge. The drawer opens as one matte surface, aligned to the same 12 px frame."
                    color: colors.textSecondary
                    wrapMode: Text.WordWrap
                    lineHeight: 1.35
                    font.family: "Inter"
                    font.pixelSize: 12
                }
                Rectangle {
                    width: parent.width
                    height: 1
                    color: colors.border
                }
                Text {
                    text: "Effects profile"
                    color: colors.textSecondary
                    font.family: "Inter"
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1
                }
                Text {
                    text: previewState.effectsProfile
                    color: colors.accent
                    font.family: "Inter"
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
                Text {
                    width: parent.width
                    text: tokens.motionDuration === 0
                          ? "Transitions are immediate."
                          : "Transitions use a restrained " + tokens.motionDuration + " ms ease."
                    color: colors.textSecondary
                    wrapMode: Text.WordWrap
                    font.family: "Inter"
                    font.pixelSize: 11
                }
            }
        }
    }
}
