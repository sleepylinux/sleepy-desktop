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
    Services.SessionEventClient { id: sessionEvents }
    Services.DailyClient { id: dailyClient }
    Services.OsdClient { id: osdClient }
    Services.ThemeClient {
        id: themeClient
        onApplyCandidateToUi: theme => {
            colors.customColors = theme.colors;
            colors.appearanceMode = theme.appearance;
            effects.effectsProfile = theme.effects;
            effects.reducedMotion = theme.reducedMotion;
            effects.opaqueFallback = theme.opaqueFallback;
        }
    }
    Services.DailyDesktopState {
        id: dailyState
        events: sessionEvents
        daily: dailyClient
        themeClient: themeClient
    }
    Services.SystemAdapter {
        id: systemAdapter
        eventSource: sessionEvents
        loadOnStartup: false
    }
    Services.PresetAdapter {
        id: presetAdapter
        activePresetId: sessionAdapter.settings.activePresetId
    }
    Services.WorkspaceEventService {
        id: workspaceService
        events: sessionEvents
        daily: dailyClient
    }
    Services.ClockService { id: clockService }
    Services.SurfaceRegistry {
        id: surfaceRegistry
        Component.onCompleted: {
            registerDescriptor({
                "id": "controlCenter", "edge": "left", "width": tokens.drawerWidth,
                "triggerIcon": "icons.control-center", "triggerLabel": "Control center",
                "availability": true, "initialFocusKey": "lock"
            });
            registerDailyDesktop();
        }
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
        eventSource: sessionEvents
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
        appearanceMode: sessionAdapter.settings.appearanceMode
        portalDark: Application.styleHints.colorScheme !== Qt.Light
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
    Drawers.DailyDesktopDrawer {
        tokens: tokens; colors: colors; effects: effects; iconRegistry: icons
        surfaceRegistry: surfaceRegistry; surfaceController: surfaces; dailyState: dailyState
    }
    Panels.OsdLayer {
        osdModel: osdClient; tokens: tokens; colors: colors; effects: effects
    }
}
