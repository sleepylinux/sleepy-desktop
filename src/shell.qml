//@ pragma ShellId sleepy

import QtQuick 6.0
import Quickshell
import "drawers" as Drawers
import "panels" as Panels
import "services" as Services
import "theme" as Theme

ShellRoot {
    id: root

    Services.SessionAdapter { id: sessionAdapter }
    Services.WorkspaceService { id: workspaceService }
    Services.ClockService { id: clockService }
    Services.QuickSettingsState { id: quickSettingsState }
    Services.SurfaceRegistry {
        id: surfaceRegistry
        Component.onCompleted: registerDescriptor({
            "id": "controlCenter",
            "edge": "left",
            "width": tokens.drawerWidth,
            "triggerIcon": "icons.control-center",
            "triggerLabel": "Control center",
            "availability": true,
            "initialFocusKey": "network"
        })
    }
    Services.SurfaceController {
        id: surfaces
        surfaceRegistry: surfaceRegistry
    }
    Services.ArtworkRegistry {
        id: artwork
        primaryMarkSource: "@sleepyPrimaryMark@"
    }
    Services.IconRegistry { id: icons }
    Theme.ThemeTokens {
        id: tokens
        reducedMotion: sessionAdapter.settings.reducedMotion
        effectsPolicy: effects
    }
    Theme.Palette {
        id: colors
        appearanceMode: sessionAdapter.settings.appearanceMode === "system"
                        ? "dark" : sessionAdapter.settings.appearanceMode
    }
    Theme.EffectsPolicy {
        id: effects
        effectsProfile: sessionAdapter.settings.effectsProfile
        reducedMotion: sessionAdapter.settings.reducedMotion
    }

    Panels.LeftRail {
        tokens: tokens
        colors: colors
        artworkRegistry: artwork
        iconRegistry: icons
        surfaceRegistry: surfaceRegistry
        surfaceController: surfaces
        workspaceService: workspaceService
        clockService: clockService
        effects: effects
    }

    Drawers.QuickSettingsDrawer {
        tokens: tokens
        colors: colors
        surfaceController: surfaces
        surfaceRegistry: surfaceRegistry
        iconRegistry: icons
        effects: effects
        quickSettingsState: quickSettingsState
        sessionAdapter: sessionAdapter
    }
}
