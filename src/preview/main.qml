import QtQuick 6.0
import QtQuick.Window 6.0
import "../drawers" as Drawers
import "../panels" as Panels
import "../services" as Services
import "../theme" as Theme
import "." as Preview

Window {
    id: root

    readonly property alias surfaceController: surfaces
    readonly property alias surfaceRegistry: previewSurfaceRegistry
    readonly property alias iconRegistry: icons
    readonly property alias previewStateObject: previewState
    readonly property alias controlCenterView: previewDrawer
    property string primaryMarkSource: "@sleepyPrimaryMark@"
    property string artworkRoot: "@sleepyArtworkRoot@"
    property string manifestSource: "@sleepyArtworkManifest@"

    width: 1280
    height: 800
    minimumWidth: 980
    minimumHeight: 680
    visible: true
    title: "Sleepy settings preview"
    color: colors.shellBackground

    Preview.PreviewState { id: previewState }
    Theme.ThemeTokens {
        id: tokens
        reducedMotion: previewState.reducedMotion
        effectsPolicy: effects
    }
    Theme.Palette {
        id: colors
        appearanceMode: previewState.appearanceMode
        portalDark: Application.styleHints.colorScheme !== Qt.Light
    }
    Theme.EffectsPolicy {
        id: effects
        effectsProfile: previewState.effectsProfile
        reducedMotion: previewState.reducedMotion
    }
    Services.SurfaceRegistry {
        id: previewSurfaceRegistry
    }
    Services.SurfaceController {
        id: surfaces
        surfaceRegistry: previewSurfaceRegistry
    }
    Services.SystemAdapterCore { id: previewSystem }
    Services.PresetAdapterCore { id: previewPresets; activePresetId: "builtin.sleepy" }
    Services.ArtworkRegistry {
        id: artwork
        primaryMarkSource: root.primaryMarkSource
    }
    Services.IconRegistry {
        id: icons
        artworkRoot: root.artworkRoot
        manifestSource: root.manifestSource
    }

    Rectangle {
        anchors.fill: parent
        color: colors.shellBackground
    }

    Column {
        id: header
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 30
        }
        spacing: tokens.gridUnit

        Column {
            width: parent.width
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

        Flow {
            width: parent.width
            spacing: 8

            Preview.PreviewChoice {
                label: "Dark"
                selected: previewState.appearanceMode === "dark"
                tokens: tokens
                colors: colors
                onTriggered: previewState.setAppearanceMode("dark")
            }
            Preview.PreviewChoice {
                label: "Confirm"
                selected: previewState.scene === "confirmation"
                tokens: tokens; colors: colors
                onTriggered: previewState.setScene("confirmation")
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
            Preview.PreviewChoice {
                label: "Presets"
                selected: previewState.scene === "presets"
                tokens: tokens; colors: colors
                onTriggered: previewState.setScene("presets")
            }
            Preview.PreviewChoice {
                label: "Conflict"
                selected: previewState.scene === "conflict"
                tokens: tokens; colors: colors
                onTriggered: previewState.setScene("conflict")
            }
            Preview.PreviewChoice {
                label: "Compact"
                selected: previewState.scene === "compact"
                tokens: tokens; colors: colors
                onTriggered: previewState.setScene("compact")
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
            surfaceRegistry: previewSurfaceRegistry
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

        Drawers.ControlCenterView {
            id: previewDrawer
            anchors {
                top: parent.top
                left: previewRail.right
                leftMargin: tokens.drawerGap
            }
            width: 408
            surfaceController: surfaces
            systemAdapter: previewSystem
            presetAdapter: previewPresets
            tokens: tokens
            colors: colors
            effects: effects
            iconRegistry: icons
            clockService: QtObject { property date currentTime: new Date(2026, 7, 24, 8, 3) }
            screenKey: "default"
            height: previewState.scene === "compact" ? 560 : parent.height
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

    Component.onCompleted: {
        const snapshot = {
            "schemaVersion": 1, "generation": 1,
            "capabilities": {
                "network.enabled": "available", "bluetooth.enabled": "available",
                "audio.volume": "available", "audio.muted": "available",
                "audio.microphoneLevel": "available", "audio.microphoneMuted": "available",
                "audio.outputDevice": "available", "display.brightness": "available",
                "display.nightLightEnabled": "available", "power.profile": "available",
                "battery.status": "available", "media.transport": "available"
            },
            "diagnostics": {},
            "sessionActions": {"lock": "available", "logout": "available", "reboot": "available", "powerOff": "available"},
            "network": {"enabled": true, "connectedName": "Sleepy Wi-Fi", "signalLevel": 0.86},
            "bluetooth": {"enabled": true, "connectedDevice": "Moonbuds"},
            "audio": {"volume": 0.62, "muted": false, "microphoneLevel": 0.48,
                "microphoneMuted": false, "outputDeviceId": "preview-speakers",
                "outputDevices": [{"id": "preview-speakers", "label": "Cozy speakers", "isDefault": true}]},
            "display": {"brightness": 0.74, "nightLightEnabled": true},
            "power": {"batteryLevel": 0.78, "charging": false, "currentProfile": "balanced",
                "availableProfiles": ["power-saver", "balanced", "performance"]},
            "media": {"title": "Lavender Hours", "artist": "Sleepy Radio", "playing": true}
        };
        previewSystem.beginSnapshot();
        previewSystem.acceptSnapshotResult(1, 0, JSON.stringify(snapshot), "", false);
        previewPresets.acceptListResult(0, JSON.stringify({"presets": [
            {"schemaVersion": 1, "id": "builtin.sleepy", "name": "Sleepy", "origin": "builtin",
             "keybindings": {"surface.controlCenter.toggle": "Mod+Shift+C"},
             "drawers": {"leftQuickSettings": {}}, "layouts": {}, "pluginRequirements": []},
            {"schemaVersion": 1, "id": "91fd2419-291f-48cc-8e03-02abb84d720c", "name": "Night work", "origin": "user",
             "basePresetId": "builtin.sleepy", "keybindings": {"surface.controlCenter.toggle": "Mod+C"},
             "drawers": {"leftQuickSettings": {}}, "layouts": {}, "pluginRequirements": []}
        ]}), "", false);
        const registered = previewSurfaceRegistry.registerDescriptor({
            "id": "controlCenter", "edge": "left", "width": tokens.drawerWidth,
            "triggerIcon": "icons.control-center", "triggerLabel": "Control center",
            "availability": true, "initialFocusKey": "lock"
        });
        if (!registered || !surfaces.open("controlCenter", "default"))
            console.warn("Sleepy preview: failed to open the default control center");
    }

    Connections {
        target: previewState
        function onPreviewChanged() {
            if (previewState.scene === "presets")
                previewDrawer.openPresets();
            else if (previewState.scene === "conflict") {
                previewDrawer.openBindings("91fd2419-291f-48cc-8e03-02abb84d720c");
                previewPresets.conflictMessage = "Binding conflict: surface.controlCenter.toggle and app.terminal.open";
                previewPresets.conflictActions = ["surface.controlCenter.toggle", "app.terminal.open"];
            } else if (previewState.scene === "confirmation") {
                previewPresets.conflictMessage = "";
                previewPresets.conflictActions = [];
                previewDrawer.requestSessionAction("reboot");
            } else {
                previewPresets.conflictMessage = "";
                previewPresets.conflictActions = [];
                previewDrawer.page = "main";
            }
        }
    }
}
