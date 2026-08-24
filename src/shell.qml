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
    Services.SystemAdapter { id: systemAdapter }
    Services.PresetAdapter {
        id: presetAdapter
        activePresetId: sessionAdapter.settings.activePresetId
    }
    Services.WorkspaceService { id: workspaceService }
    Services.ClockService { id: clockService }
    Services.SurfaceRegistry {
        id: surfaceRegistry
        Component.onCompleted: registerDescriptor({
            "id": "controlCenter",
            "edge": "left",
            "width": tokens.drawerWidth,
            "triggerIcon": "icons.control-center",
            "triggerLabel": "Control center",
            "availability": true,
            "initialFocusKey": "lock"
        })
    }
    Services.SurfaceController {
        id: surfaces
        surfaceRegistry: surfaceRegistry
    }
    Services.ShortcutRouter {
        id: shortcutRouter
        surfaceController: surfaces
        onSessionActionRequested: (action, outputName) => {
            if (!systemAdapter.sessionActionAvailable(action))
                return;
            if (action === "lock")
                systemAdapter.perform("lock", "confirmed");
            else
                surfaces.requestSessionConfirmation(action, outputName);
        }
    }
    Services.ShellIpc {
        shortcutRouter: shortcutRouter
        surfaceController: surfaces
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
        clockService: clockService
        surfaceRegistry: surfaceRegistry
        surfaceController: surfaces
        workspaceService: workspaceService
        effects: effects
    }

    Drawers.ControlCenterDrawer {
        tokens: tokens
        colors: colors
        surfaceController: surfaces
        surfaceRegistry: surfaceRegistry
        iconRegistry: icons
        clockService: clockService
        effects: effects
        systemAdapter: systemAdapter
        presetAdapter: presetAdapter
    }
}
