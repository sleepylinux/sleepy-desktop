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
    Services.SurfaceController {
        id: surfaces
        Component.onCompleted: registerSurface("quickSettings", "left")
    }
    Services.ArtworkRegistry {
        id: artwork
        primaryMarkSource: "@sleepyPrimaryMark@"
    }
    Theme.ThemeTokens {
        id: tokens
        reducedMotion: sessionAdapter.settings.reducedMotion
    }
    Theme.Palette {
        id: colors
        appearanceMode: sessionAdapter.settings.appearanceMode === "system"
                        ? "dark" : sessionAdapter.settings.appearanceMode
    }

    Panels.LeftRail {
        tokens: tokens
        colors: colors
        artworkRegistry: artwork
        surfaceController: surfaces
        workspaceService: workspaceService
        clockService: clockService
    }

    Drawers.QuickSettingsDrawer {
        tokens: tokens
        colors: colors
        surfaceController: surfaces
        quickSettingsState: quickSettingsState
        sessionAdapter: sessionAdapter
    }
}
