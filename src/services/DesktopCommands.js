.pragma library

function stableId(value) {
    return typeof value === "string" && value.trim() === value && value.length > 0 ? value : "";
}

function positiveInteger(value) {
    return Number.isSafeInteger(value) && value > 0 ? value : 0;
}

function normalized(value) {
    return Number.isFinite(value) ? Math.max(0, Math.min(1, value)) : null;
}

function systemDomain(domain, action) {
    return action ? {"domain": domain, "action": action} : null;
}

function networkSetWifiEnabled(enabled) {
    return systemDomain("network", {
        "type": "setWifiEnabled",
        "data": {"enabled": Boolean(enabled)}
    });
}

function networkScanWifi() {
    return systemDomain("network", {"type": "scanWifi"});
}

function networkConnectWifi(accessPointId) {
    const id = stableId(accessPointId);
    return id ? systemDomain("network", {
        "type": "connectWifi",
        "data": {"accessPointId": id}
    }) : null;
}

function networkDisconnect(connectionId) {
    const id = stableId(connectionId);
    return id ? systemDomain("network", {
        "type": "disconnect",
        "data": {"connectionId": id}
    }) : null;
}

function audioSetDefaultNode(nodeId) {
    const id = stableId(nodeId);
    return id ? systemDomain("audio", {
        "type": "setDefaultNode",
        "data": {"nodeId": id}
    }) : null;
}

function audioSetNodeVolume(nodeId, level) {
    const id = stableId(nodeId);
    const bounded = normalized(level);
    return id && bounded !== null ? systemDomain("audio", {
        "type": "setNodeVolume",
        "data": {"nodeId": id, "level": bounded}
    }) : null;
}

function audioSetNodeMuted(nodeId, muted) {
    const id = stableId(nodeId);
    return id ? systemDomain("audio", {
        "type": "setNodeMuted",
        "data": {"nodeId": id, "muted": Boolean(muted)}
    }) : null;
}

function audioSetStreamVolume(streamId, level) {
    const id = stableId(streamId);
    const bounded = normalized(level);
    return id && bounded !== null ? systemDomain("audio", {
        "type": "setStreamVolume",
        "data": {"streamId": id, "level": bounded}
    }) : null;
}

function audioSetStreamMuted(streamId, muted) {
    const id = stableId(streamId);
    return id ? systemDomain("audio", {
        "type": "setStreamMuted",
        "data": {"streamId": id, "muted": Boolean(muted)}
    }) : null;
}

function mediaTransport(playerId, transport) {
    const id = stableId(playerId);
    if (!id || ["playPause", "next", "previous"].indexOf(transport) < 0)
        return null;
    return systemDomain("media", {
        "type": "transport",
        "data": {"playerId": id, "transport": transport}
    });
}

function displaySetBrightness(outputId, level) {
    const id = stableId(outputId);
    const bounded = normalized(level);
    return id && bounded !== null ? systemDomain("display", {
        "type": "setBrightness",
        "data": {"outputId": id, "level": bounded}
    }) : null;
}

function displaySetNightLightEnabled(enabled) {
    return systemDomain("display", {
        "type": "setNightLightEnabled",
        "data": {"enabled": Boolean(enabled)}
    });
}

function powerSetProfile(profile) {
    return ["power-saver", "balanced", "performance"].indexOf(profile) >= 0
        ? systemDomain("power", {"type": "setProfile", "data": {"profile": profile}})
        : null;
}

function compositor(type, data) {
    const payload = data || {};
    switch (type) {
    case "focusWindow":
    case "closeWindow":
    case "toggleFullscreen":
    case "toggleFloating":
    case "togglePinned":
    case "toggleGroup": {
        const windowId = stableId(payload.windowId);
        return windowId ? {"type": type, "data": {"windowId": windowId}} : null;
    }
    case "focusWorkspace": {
        const workspaceId = stableId(payload.workspaceId);
        return workspaceId ? {"type": type, "data": {"workspaceId": workspaceId}} : null;
    }
    case "moveWindowToWorkspace": {
        const windowId = stableId(payload.windowId);
        const workspaceId = stableId(payload.workspaceId);
        return windowId && workspaceId ? {
            "type": type,
            "data": {"windowId": windowId, "workspaceId": workspaceId}
        } : null;
    }
    case "moveWorkspaceToMonitor": {
        const workspaceId = stableId(payload.workspaceId);
        const monitorId = stableId(payload.monitorId);
        return workspaceId && monitorId ? {
            "type": type,
            "data": {"workspaceId": workspaceId, "monitorId": monitorId}
        } : null;
    }
    case "exit":
        return {"type": "exit"};
    default:
        return null;
    }
}

function notificationSetDnd(enabled) {
    return {"type": "setDnd", "data": {"enabled": Boolean(enabled)}};
}

function notificationArchive(notificationId) {
    const id = positiveInteger(notificationId);
    return id ? {"type": "archive", "data": {"notificationId": id}} : null;
}

function notificationInvokeAction(notificationId, actionId) {
    const id = positiveInteger(notificationId);
    const action = stableId(actionId);
    return id && action ? {
        "type": "invokeAction",
        "data": {"notificationId": id, "actionId": action}
    } : null;
}

function launcherLaunch(desktopId, resources, actionId) {
    const id = stableId(desktopId);
    if (!id)
        return null;
    const data = {"schemaVersion": 2, "desktopId": id, "resources": Array.isArray(resources) ? resources : []};
    const action = stableId(actionId || "");
    if (action)
        data.actionId = action;
    return {"type": "launch", "data": data};
}

function appearanceApplyTheme(themeId) {
    const id = stableId(themeId);
    return id ? {"type": "applyTheme", "data": {"themeId": id}} : null;
}

function appearanceSetWallpaper(wallpaperId) {
    const id = stableId(wallpaperId);
    return id ? {"type": "setWallpaper", "data": {"wallpaperId": id}} : null;
}

function appearanceSetReducedMotion(enabled) {
    return {"type": "setReducedMotion", "data": {"enabled": Boolean(enabled)}};
}

function appearanceSetOpaque(enabled) {
    return {"type": "setOpaque", "data": {"enabled": Boolean(enabled)}};
}

function appearancePreviewWallpaper(_wallpaperId) {
    return null;
}

function utilitySetIdleInhibited(enabled) {
    return {"type": "setIdleInhibited", "data": {"enabled": Boolean(enabled)}};
}

function utilityStartRecording(outputId) {
    const id = stableId(outputId);
    return id ? {"type": "startRecording", "data": {"outputId": id}} : null;
}

function utilityPauseRecording() {
    return {"type": "pauseRecording"};
}

function utilityStopRecording() {
    return {"type": "stopRecording"};
}

function utilityScreenshot(outputId) {
    const id = stableId(outputId);
    return id ? {"type": "screenshot", "data": {"outputId": id}} : null;
}

function utilitySetGameMode(enabled) {
    return {"type": "setGameMode", "data": {"enabled": Boolean(enabled)}};
}

function session(action) {
    return ["lock", "suspend", "logout", "reboot", "powerOff"].indexOf(action) >= 0
        ? action : null;
}
