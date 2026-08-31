.pragma library

function own(object, key) {
    return object && Object.prototype.hasOwnProperty.call(object, key);
}

function exact(value, required, optional) {
    if (!value || typeof value !== "object" || Array.isArray(value))
        return false;
    const allowed = required.concat(optional || []);
    const keys = Object.keys(value);
    return required.every(key => keys.indexOf(key) >= 0)
        && keys.every(key => allowed.indexOf(key) >= 0);
}

function oneOf(value, values) {
    return values.indexOf(value) >= 0;
}

function noControlCharacters(value) {
    return !/[\x00-\x1f\x7f-\x9f]/.test(value);
}

function stableId(value) {
    return typeof value === "string"
        && value.trim() === value
        && value.length > 0
        && value.length <= 256
        && noControlCharacters(value) ? value : "";
}

function validStableId(value) {
    return stableId(value) === value;
}

function positiveInteger(value) {
    return Number.isSafeInteger(value) && value > 0 ? value : 0;
}

function normalized(value) {
    return typeof value === "number" && Number.isFinite(value)
        && value >= 0 && value <= 1 ? value : null;
}

function booleanValue(value) {
    return typeof value === "boolean" ? value : null;
}

function enabledData(enabled) {
    const value = booleanValue(enabled);
    return value === null ? null : {"enabled": value};
}

function systemDomain(domain, action) {
    return action ? {"domain": domain, "action": action} : null;
}

function stableField(key, value) {
    const id = stableId(value);
    const data = {};
    if (!id)
        return null;
    data[key] = id;
    return data;
}

function validStableField(value, key) {
    return exact(value, [key], []) && validStableId(value[key]);
}

function validEnabledData(value) {
    return exact(value, ["enabled"], []) && typeof value.enabled === "boolean";
}

function validLauncherResource(value) {
    return typeof value === "string"
        && value.length > 0
        && value.length <= 4096
        && value.indexOf("\u0000") < 0;
}

function validLauncherResources(resources) {
    if (!Array.isArray(resources) || resources.length > 4096)
        return false;
    return resources.every(resource => validLauncherResource(resource));
}

function desktopEntryId(value) {
    const id = stableId(value);
    if (!id || id === ".desktop")
        return "";
    return /^(?!.*\.\.)[^\/\\\x00-\x1f\x7f-\x9f]+\.desktop$/.test(id) ? id : "";
}

function validLauncherData(data) {
    return exact(data, ["schemaVersion", "desktopId", "resources"], ["actionId"])
        && data.schemaVersion === 2
        && desktopEntryId(data.desktopId) === data.desktopId
        && validLauncherResources(data.resources)
        && (!own(data, "actionId") || validStableId(data.actionId));
}

function validFamily(family) {
    return ["system", "compositor", "notification", "launcher",
            "appearance", "utility", "session"].indexOf(family) >= 0;
}

function networkSetWifiEnabled(enabled) {
    const data = enabledData(enabled);
    return data ? systemDomain("network", {
        "type": "setWifiEnabled",
        "data": data
    }) : null;
}

function networkScanWifi() {
    return systemDomain("network", {"type": "scanWifi"});
}

function networkConnectWifi(accessPointId) {
    const data = stableField("accessPointId", accessPointId);
    return data ? systemDomain("network", {
        "type": "connectWifi",
        "data": data
    }) : null;
}

function networkDisconnect(connectionId) {
    const data = stableField("connectionId", connectionId);
    return data ? systemDomain("network", {
        "type": "disconnect",
        "data": data
    }) : null;
}

function audioSetDefaultNode(nodeId) {
    const data = stableField("nodeId", nodeId);
    return data ? systemDomain("audio", {
        "type": "setDefaultNode",
        "data": data
    }) : null;
}

function audioSetNodeVolume(nodeId, level) {
    const data = stableField("nodeId", nodeId);
    const bounded = normalized(level);
    return data && bounded !== null ? systemDomain("audio", {
        "type": "setNodeVolume",
        "data": {"nodeId": data.nodeId, "level": bounded}
    }) : null;
}

function audioSetNodeMuted(nodeId, muted) {
    const data = stableField("nodeId", nodeId);
    const value = booleanValue(muted);
    return data && value !== null ? systemDomain("audio", {
        "type": "setNodeMuted",
        "data": {"nodeId": data.nodeId, "muted": value}
    }) : null;
}

function audioSetStreamVolume(streamId, level) {
    const data = stableField("streamId", streamId);
    const bounded = normalized(level);
    return data && bounded !== null ? systemDomain("audio", {
        "type": "setStreamVolume",
        "data": {"streamId": data.streamId, "level": bounded}
    }) : null;
}

function audioSetStreamMuted(streamId, muted) {
    const data = stableField("streamId", streamId);
    const value = booleanValue(muted);
    return data && value !== null ? systemDomain("audio", {
        "type": "setStreamMuted",
        "data": {"streamId": data.streamId, "muted": value}
    }) : null;
}

function mediaTransport(playerId, transport) {
    const data = stableField("playerId", playerId);
    if (!data || ["playPause", "next", "previous"].indexOf(transport) < 0)
        return null;
    return systemDomain("media", {
        "type": "transport",
        "data": {"playerId": data.playerId, "transport": transport}
    });
}

function displaySetBrightness(outputId, level) {
    const data = stableField("outputId", outputId);
    const bounded = normalized(level);
    return data && bounded !== null ? systemDomain("display", {
        "type": "setBrightness",
        "data": {"outputId": data.outputId, "level": bounded}
    }) : null;
}

function displaySetNightLightEnabled(enabled) {
    const data = enabledData(enabled);
    return data ? systemDomain("display", {
        "type": "setNightLightEnabled",
        "data": data
    }) : null;
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
        const ids = stableField("windowId", payload.windowId);
        return ids ? {"type": type, "data": ids} : null;
    }
    case "focusWorkspace": {
        const ids = stableField("workspaceId", payload.workspaceId);
        return ids ? {"type": type, "data": ids} : null;
    }
    case "moveWindowToWorkspace": {
        const windowIds = stableField("windowId", payload.windowId);
        const workspaceIds = stableField("workspaceId", payload.workspaceId);
        return windowIds && workspaceIds ? {
            "type": type,
            "data": {"windowId": windowIds.windowId, "workspaceId": workspaceIds.workspaceId}
        } : null;
    }
    case "moveWorkspaceToMonitor": {
        const workspaceIds = stableField("workspaceId", payload.workspaceId);
        const monitorIds = stableField("monitorId", payload.monitorId);
        return workspaceIds && monitorIds ? {
            "type": type,
            "data": {"workspaceId": workspaceIds.workspaceId, "monitorId": monitorIds.monitorId}
        } : null;
    }
    case "exit":
        return {"type": "exit"};
    default:
        return null;
    }
}

function notificationSetDnd(enabled) {
    const data = enabledData(enabled);
    return data ? {"type": "setDnd", "data": data} : null;
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
    const id = desktopEntryId(desktopId);
    if (!id || !validLauncherResources(resources))
        return null;
    const data = {"schemaVersion": 2, "desktopId": id, "resources": resources.slice()};
    if (actionId !== undefined && actionId !== null && actionId !== "") {
        const action = stableId(actionId);
        if (!action)
            return null;
        data.actionId = action;
    }
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
    const data = enabledData(enabled);
    return data ? {"type": "setReducedMotion", "data": data} : null;
}

function appearanceSetOpaque(enabled) {
    const data = enabledData(enabled);
    return data ? {"type": "setOpaque", "data": data} : null;
}

function appearancePreviewWallpaper(_wallpaperId) {
    return null;
}

function utilitySetIdleInhibited(enabled) {
    const data = enabledData(enabled);
    return data ? {"type": "setIdleInhibited", "data": data} : null;
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
    const data = enabledData(enabled);
    return data ? {"type": "setGameMode", "data": data} : null;
}

function session(action) {
    return ["lock", "suspend", "logout", "reboot", "powerOff"].indexOf(action) >= 0
        ? action : null;
}

function validLegacySystemMutation(command) {
    if (!exact(command, ["capability", "value"], []))
        return false;
    switch (command.capability) {
    case "network.enabled":
    case "bluetooth.enabled":
    case "audio.muted":
    case "audio.microphoneMuted":
    case "display.nightLightEnabled":
        return typeof command.value === "boolean";
    case "audio.volume":
    case "audio.microphoneLevel":
    case "display.brightness":
        return normalized(command.value) !== null;
    case "audio.outputDevice":
        return validStableId(command.value);
    case "power.profile":
        return oneOf(command.value, ["power-saver", "balanced", "performance"]);
    case "media.transport":
        return oneOf(command.value, ["playPause", "next", "previous"]);
    default:
        return false;
    }
}

function validNetworkAction(action) {
    if (exact(action, ["type"], []) && action.type === "scanWifi")
        return true;
    if (!exact(action, ["type", "data"], []))
        return false;
    switch (action.type) {
    case "setWifiEnabled":
        return validEnabledData(action.data);
    case "connectWifi":
        return validStableField(action.data, "accessPointId");
    case "disconnect":
        return validStableField(action.data, "connectionId");
    default:
        return false;
    }
}

function validBluetoothAction(action) {
    if (exact(action, ["type"], []) && action.type === "scan")
        return true;
    if (!exact(action, ["type", "data"], []))
        return false;
    switch (action.type) {
    case "setPowered":
        return exact(action.data, ["powered"], []) && typeof action.data.powered === "boolean";
    case "pair":
    case "connect":
    case "disconnect":
        return validStableField(action.data, "deviceId");
    default:
        return false;
    }
}

function validAudioAction(action) {
    if (!exact(action, ["type", "data"], []))
        return false;
    switch (action.type) {
    case "setDefaultNode":
        return validStableField(action.data, "nodeId");
    case "setNodeVolume":
        return exact(action.data, ["nodeId", "level"], [])
            && validStableId(action.data.nodeId)
            && normalized(action.data.level) !== null;
    case "setNodeMuted":
        return exact(action.data, ["nodeId", "muted"], [])
            && validStableId(action.data.nodeId)
            && typeof action.data.muted === "boolean";
    case "setStreamVolume":
        return exact(action.data, ["streamId", "level"], [])
            && validStableId(action.data.streamId)
            && normalized(action.data.level) !== null;
    case "setStreamMuted":
        return exact(action.data, ["streamId", "muted"], [])
            && validStableId(action.data.streamId)
            && typeof action.data.muted === "boolean";
    default:
        return false;
    }
}

function validMediaAction(action) {
    return exact(action, ["type", "data"], [])
        && action.type === "transport"
        && exact(action.data, ["playerId", "transport"], [])
        && validStableId(action.data.playerId)
        && oneOf(action.data.transport, ["playPause", "next", "previous"]);
}

function validDisplayAction(action) {
    if (!exact(action, ["type", "data"], []))
        return false;
    switch (action.type) {
    case "setBrightness":
        return exact(action.data, ["outputId", "level"], [])
            && validStableId(action.data.outputId)
            && normalized(action.data.level) !== null;
    case "setNightLightEnabled":
        return validEnabledData(action.data);
    default:
        return false;
    }
}

function validSystemDomainCommand(command) {
    if (!exact(command, ["domain", "action"], []))
        return false;
    switch (command.domain) {
    case "network":
        return validNetworkAction(command.action);
    case "bluetooth":
        return validBluetoothAction(command.action);
    case "audio":
        return validAudioAction(command.action);
    case "media":
        return validMediaAction(command.action);
    case "display":
        return validDisplayAction(command.action);
    case "power":
        return exact(command.action, ["type", "data"], [])
            && command.action.type === "setProfile"
            && exact(command.action.data, ["profile"], [])
            && oneOf(command.action.data.profile, ["power-saver", "balanced", "performance"]);
    default:
        return false;
    }
}

function validSystemCommand(command) {
    return validSystemDomainCommand(command) || validLegacySystemMutation(command);
}

function validHyprlandCommand(command) {
    if (exact(command, ["type"], []) && command.type === "exit")
        return true;
    if (!exact(command, ["type", "data"], []))
        return false;
    switch (command.type) {
    case "focusWindow":
    case "closeWindow":
    case "toggleFullscreen":
    case "toggleFloating":
    case "togglePinned":
    case "toggleGroup":
        return validStableField(command.data, "windowId");
    case "focusWorkspace":
        return validStableField(command.data, "workspaceId");
    case "moveWindowToWorkspace":
        return exact(command.data, ["windowId", "workspaceId"], [])
            && validStableId(command.data.windowId)
            && validStableId(command.data.workspaceId);
    case "moveWorkspaceToMonitor":
        return exact(command.data, ["workspaceId", "monitorId"], [])
            && validStableId(command.data.workspaceId)
            && validStableId(command.data.monitorId);
    default:
        return false;
    }
}

function validNotificationCommand(command) {
    if (!exact(command, ["type", "data"], []))
        return false;
    switch (command.type) {
    case "setDnd":
        return validEnabledData(command.data);
    case "archive":
        return exact(command.data, ["notificationId"], [])
            && positiveInteger(command.data.notificationId) === command.data.notificationId;
    case "invokeAction":
        return exact(command.data, ["notificationId", "actionId"], [])
            && positiveInteger(command.data.notificationId) === command.data.notificationId
            && validStableId(command.data.actionId);
    default:
        return false;
    }
}

function validLauncherCommand(command) {
    return exact(command, ["type", "data"], [])
        && command.type === "launch"
        && validLauncherData(command.data);
}

function validAppearanceCommand(command) {
    if (!exact(command, ["type", "data"], []))
        return false;
    switch (command.type) {
    case "applyTheme":
        return validStableField(command.data, "themeId");
    case "setWallpaper":
        return validStableField(command.data, "wallpaperId");
    case "setReducedMotion":
    case "setOpaque":
        return validEnabledData(command.data);
    default:
        return false;
    }
}

function validUtilityCommand(command) {
    if (exact(command, ["type"], [])
            && oneOf(command.type, ["clearClipboard", "pauseRecording", "stopRecording", "pickColor"]))
        return true;
    if (!exact(command, ["type", "data"], []))
        return false;
    switch (command.type) {
    case "invokeTrayMenu":
        return exact(command.data, ["itemId", "menuId"], [])
            && validStableId(command.data.itemId)
            && validStableId(command.data.menuId);
    case "pasteClipboard":
        return validStableField(command.data, "entryId");
    case "setIdleInhibited":
    case "setGameMode":
        return validEnabledData(command.data);
    case "startRecording":
    case "screenshot":
        return validStableField(command.data, "outputId");
    default:
        return false;
    }
}

function validCommand(family, command) {
    switch (family) {
    case "system":
        return validSystemCommand(command);
    case "compositor":
        return validHyprlandCommand(command);
    case "notification":
        return validNotificationCommand(command);
    case "launcher":
        return validLauncherCommand(command);
    case "appearance":
        return validAppearanceCommand(command);
    case "utility":
        return validUtilityCommand(command);
    case "session":
        return session(command) === command;
    default:
        return false;
    }
}
