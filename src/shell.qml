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
    Services.ControlClient { id: controlClient; events: sessionEvents }
    Services.NotificationClient { id: notificationClient; events: sessionEvents }
    Services.DailyClient { id: dailyClient }
    Services.OsdClient { id: osdClient }
    Services.ThemeClient {
        id: themeClient
        candidateApplier: function(theme) {
            colors.customColors = theme.colors;
            colors.appearanceMode = theme.appearance;
            effects.effectsProfile = theme.effects;
            effects.reducedMotion = theme.reducedMotion;
            effects.opaqueFallback = theme.opaqueFallback;
            const applied = colors.customColors === theme.colors
                && colors.appearanceMode === theme.appearance
                && effects.effectsProfile === theme.effects
                && effects.reducedMotion === theme.reducedMotion
                && effects.opaqueFallback === theme.opaqueFallback;
            if (!applied && themeClient.confirmedTheme
                    && themeClient.confirmedTheme.id !== theme.id)
                themeClient.candidateApplier(themeClient.confirmedTheme);
            return applied;
        }
    }
    Services.DailyDesktopState {
        id: dailyState
        events: sessionEvents
        daily: dailyClient
        themeClient: themeClient
        notificationClient: notificationClient
    }
    Services.SystemAdapter {
        id: systemAdapter
        eventSource: sessionEvents
        controlClient: controlClient
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
        function refreshDailyAvailability() {
            const sessionReady = sessionEvents.connectionState === "ready";
            setAvailability("notifications", sessionReady && notificationClient.status !== "error");
            setAvailability("launcher", sessionReady && dailyClient.status !== "offline");
            setAvailability("overview", sessionReady && sessionEvents.capability("niri").available);
            setAvailability("widgets", sessionReady && dailyClient.status !== "offline");
            setAvailability("personalization", themeClient.startupComplete
                && ["unavailable", "error"].indexOf(themeClient.status) < 0);
        }
        Component.onCompleted: {
            registerDescriptor({
                "id": "controlCenter", "edge": "left", "width": tokens.drawerWidth,
                "triggerIcon": "icons.control-center", "triggerLabel": "Control center",
                "availability": true, "initialFocusKey": "lock"
            });
            registerDailyDesktop();
            refreshDailyAvailability();
        }
    }
    Connections {
        target: sessionEvents
        function onConnectionStateChanged() { surfaceRegistry.refreshDailyAvailability(); }
        function onEventAccepted() { surfaceRegistry.refreshDailyAvailability(); }
    }
    Connections {
        target: dailyClient
        function onStatusChanged() { surfaceRegistry.refreshDailyAvailability(); }
    }
    Connections {
        target: notificationClient
        function onStatusChanged() { surfaceRegistry.refreshDailyAvailability(); }
    }
    Connections {
        target: themeClient
        function onStatusChanged() { surfaceRegistry.refreshDailyAvailability(); }
        function onStartupCompleteChanged() { surfaceRegistry.refreshDailyAvailability(); }
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
