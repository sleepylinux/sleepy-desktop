// SPDX-License-Identifier: GPL-3.0-only
// Modified for Sleepy on 2026-08-31: daemon-owned desktop runtime protocol.

import QtQuick 6.0

QtObject {
    id: root

    property string eventSocketPath: ""
    property string controlSocketPath: ""
    property int minimumRetryMs: 250
    property int maximumRetryMs: 10000
    property int maximumObservedRequests: 64
    property string connectionState: "offline"
    property string diagnostic: "Waiting for sleepy-sessiond"
    property var generation: 0
    property var snapshot: Object.freeze({})
    property var observedRequestIds: Object.freeze({})
    property var observedRequestOrder: Object.freeze([])
    property var lastCommandResult: null
    property bool snapshotReceived: false
    readonly property int maximumMenuNodes: 65536
    readonly property int maximumMenuDepth: 1024

    signal eventAccepted(var envelope)
    signal commandResultAccepted(var result)
    signal protocolError(string message)
    signal daemonGenerationChanged(var generation)

    readonly property var topics: Object.freeze([
        "system", "compositor", "notifications", "launcher", "calendar",
        "weather", "appearance", "resources", "utilities"
    ])

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

    function canonicalUuid(value) {
        return typeof value === "string"
            && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(value);
    }

    function positiveInteger(value) {
        return Number.isSafeInteger(value) && value > 0;
    }

    function positiveU32(value) {
        return Number.isSafeInteger(value) && value > 0 && value <= 4294967295;
    }

    function unsignedInteger(value) {
        return Number.isSafeInteger(value) && value >= 0;
    }

    function finitePositive(value) {
        return Number.isFinite(value) && value > 0;
    }

    function normalized(value) {
        return Number.isFinite(value) && value >= 0 && value <= 1;
    }

    function nonEmpty(value) {
        return typeof value === "string" && value.trim() === value && value.length > 0;
    }

    function validTimestamp(value) {
        return root.nonEmpty(value)
            && /^(?!0000)(?:(?:[0-9]{4}-(?:(?:0[13578]|1[02])-(?:0[1-9]|[12][0-9]|3[01])|(?:0[469]|11)-(?:0[1-9]|[12][0-9]|30)|02-(?:0[1-9]|1[0-9]|2[0-8])))|(?:(?:[0-9]{2}(?:0[48]|[2468][048]|[13579][26])|(?:[02468][048]|[13579][26])00)-02-29))T(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](?:\.[0-9]+)?Z$/.test(value)
            && !Number.isNaN(Date.parse(value));
    }

    function validColor(value) {
        return typeof value === "string" && /^#[0-9a-fA-F]{6}$/.test(value);
    }

    function oneOf(value, values) {
        return values.indexOf(value) >= 0;
    }

    function validArray(value, maximum, validator) {
        if (!Array.isArray(value) || (maximum >= 0 && value.length > maximum))
            return false;
        return value.every(item => validator(item));
    }

    function validUniqueArray(value, maximum, validator, key) {
        if (!Array.isArray(value) || (maximum >= 0 && value.length > maximum))
            return false;
        const seen = Object.create(null);
        for (const item of value) {
            if (!validator(item))
                return false;
            const identifier = item[key];
            if ((typeof identifier !== "string" && !Number.isSafeInteger(identifier))
                    || root.own(seen, String(identifier)))
                return false;
            seen[String(identifier)] = true;
        }
        return true;
    }

    function idSet(items) {
        const ids = Object.create(null);
        for (const item of items)
            ids[item.id] = true;
        return ids;
    }

    function focusedCount(items) {
        let count = 0;
        for (const item of items) {
            if (item.focused)
                ++count;
        }
        return count;
    }

    function validDiagnostic(value) {
        return root.exact(value, ["message"], [])
            && root.nonEmpty(value.message);
    }

    function validUnavailableCapability(value) {
        return root.exact(value, ["status", "diagnostic"], [])
            && root.oneOf(value.status, [
                "unavailable", "unsupported", "permissionDenied",
                "timeout", "parse", "error"
            ])
            && root.validDiagnostic(value.diagnostic);
    }

    function validCapability(value, validator) {
        if (root.exact(value, ["status", "data"], [])
                && value.status === "available")
            return validator(value.data);
        return root.validUnavailableCapability(value);
    }

    function validProducerAvailability(value) {
        return root.exact(value, ["status"], []) && value.status === "available"
            || root.validUnavailableCapability(value);
    }

    function validNetwork(value) {
        return root.exact(value, ["wifiEnabled", "scanning", "accessPoints", "connections"], [])
            && typeof value.wifiEnabled === "boolean"
            && typeof value.scanning === "boolean"
            && root.validUniqueArray(value.accessPoints, 4096, root.validAccessPoint, "id")
            && root.validUniqueArray(value.connections, -1, root.validConnection, "id");
    }

    function validAccessPoint(value) {
        return root.exact(value, ["id", "ssid", "signalLevel", "secured"], [])
            && root.nonEmpty(value.id)
            && root.nonEmpty(value.ssid)
            && root.normalized(value.signalLevel)
            && typeof value.secured === "boolean";
    }

    function validConnection(value) {
        return root.exact(value, ["id", "name", "kind", "connected"], [])
            && root.nonEmpty(value.id)
            && root.nonEmpty(value.name)
            && root.oneOf(value.kind, ["ethernet", "wifi", "vpn"])
            && typeof value.connected === "boolean";
    }

    function validBluetooth(value) {
        return root.exact(value, ["powered", "scanning", "devices"], [])
            && typeof value.powered === "boolean"
            && typeof value.scanning === "boolean"
            && root.validUniqueArray(value.devices, 1024, root.validBluetoothDevice, "id");
    }

    function validBluetoothDevice(value) {
        return root.exact(value, ["id", "name", "paired", "connected"], [])
            && root.nonEmpty(value.id)
            && root.nonEmpty(value.name)
            && typeof value.paired === "boolean"
            && typeof value.connected === "boolean";
    }

    function validAudio(value) {
        if (!root.exact(value, ["nodes", "streams"], [])
                || !root.validUniqueArray(value.nodes, 4096, root.validAudioNode, "id")
                || !root.validUniqueArray(value.streams, 16384, root.validAudioStream, "id"))
            return false;
        const nodeIds = root.idSet(value.nodes);
        for (const stream of value.streams) {
            if (!root.own(nodeIds, stream.nodeId))
                return false;
        }
        return true;
    }

    function validAudioNode(value) {
        return root.exact(value, ["id", "name", "kind", "volume", "muted", "isDefault"], [])
            && root.nonEmpty(value.id)
            && root.nonEmpty(value.name)
            && root.oneOf(value.kind, ["input", "output"])
            && root.normalized(value.volume)
            && typeof value.muted === "boolean"
            && typeof value.isDefault === "boolean";
    }

    function validAudioStream(value) {
        return root.exact(value, ["id", "name", "nodeId", "volume", "muted"], [])
            && root.nonEmpty(value.id)
            && root.nonEmpty(value.name)
            && root.nonEmpty(value.nodeId)
            && root.normalized(value.volume)
            && typeof value.muted === "boolean";
    }

    function validMedia(value) {
        return root.exact(value, ["players"], [])
            && root.validUniqueArray(value.players, 256, root.validPlayer, "id");
    }

    function validPlayer(value) {
        return root.exact(value, ["id", "identity", "title", "artist", "playing", "progress"], [])
            && root.nonEmpty(value.id)
            && root.nonEmpty(value.identity)
            && typeof value.title === "string"
            && typeof value.artist === "string"
            && typeof value.playing === "boolean"
            && root.normalized(value.progress);
    }

    function validBattery(value) {
        return root.exact(value, ["level", "charging"], ["secondsRemaining"])
            && root.normalized(value.level)
            && typeof value.charging === "boolean"
            && (!root.own(value, "secondsRemaining") || root.unsignedInteger(value.secondsRemaining));
    }

    function validBrightness(value) {
        return root.exact(value, ["level"], [])
            && root.normalized(value.level);
    }

    function validNightLight(value) {
        return root.exact(value, ["enabled"], [])
            && typeof value.enabled === "boolean";
    }

    function validPower(value) {
        if (!root.exact(value, ["activeProfile", "availableProfiles"], [])
                || !root.oneOf(value.activeProfile, ["power-saver", "balanced", "performance"])
                || !Array.isArray(value.availableProfiles) || value.availableProfiles.length < 1)
            return false;
        const seen = Object.create(null);
        for (const profile of value.availableProfiles) {
            if (!root.oneOf(profile, ["power-saver", "balanced", "performance"])
                    || root.own(seen, profile))
                return false;
            seen[profile] = true;
        }
        return root.own(seen, value.activeProfile);
    }

    function validOsd(value) {
        return root.exact(value, ["history"], ["current"])
            && (!root.own(value, "current") || root.validOsdEvent(value.current))
            && root.validArray(value.history, 500, root.validOsdEvent);
    }

    function validOsdEvent(value) {
        if (!root.exact(value, ["schemaVersion", "outputId", "kind", "label"], ["level", "muted"])
                || value.schemaVersion !== 2
                || !root.nonEmpty(value.outputId)
                || !root.oneOf(value.kind, ["volume", "microphone", "brightness", "media", "powerProfile"])
                || !root.nonEmpty(value.label))
            return false;
        if (root.oneOf(value.kind, ["volume", "microphone", "brightness"])
                && (!root.own(value, "level") || !root.normalized(value.level)))
            return false;
        if (value.kind === "brightness" && root.own(value, "muted"))
            return false;
        return !root.own(value, "muted") || typeof value.muted === "boolean";
    }

    function validLock(value) {
        return root.exact(value, ["secure"], [])
            && typeof value.secure === "boolean";
    }

    function validSystem(value) {
        return root.exact(value, [
            "network", "bluetooth", "audio", "media", "battery",
            "brightness", "nightLight", "power", "osd", "lock"
        ], [])
            && root.validNetworkCapability(value.network)
            && root.validBluetoothCapability(value.bluetooth)
            && root.validAudioCapability(value.audio)
            && root.validMediaCapability(value.media)
            && root.validBatteryCapability(value.battery)
            && root.validBrightnessCapability(value.brightness)
            && root.validNightLightCapability(value.nightLight)
            && root.validPowerCapability(value.power)
            && root.validOsdCapability(value.osd)
            && root.validLockCapability(value.lock);
    }

    function validNetworkCapability(value) {
        return root.validCapability(value, root.validNetwork);
    }

    function validBluetoothCapability(value) {
        return root.validCapability(value, root.validBluetooth);
    }

    function validAudioCapability(value) {
        return root.validCapability(value, root.validAudio);
    }

    function validMediaCapability(value) {
        return root.validCapability(value, root.validMedia);
    }

    function validBatteryCapability(value) {
        return root.validCapability(value, root.validBattery);
    }

    function validBrightnessCapability(value) {
        return root.validCapability(value, root.validBrightness);
    }

    function validNightLightCapability(value) {
        return root.validCapability(value, root.validNightLight);
    }

    function validPowerCapability(value) {
        return root.validCapability(value, root.validPower);
    }

    function validOsdCapability(value) {
        return root.validCapability(value, root.validOsd);
    }

    function validLockCapability(value) {
        return root.validCapability(value, root.validLock);
    }

    function validHyprlandActionCapabilities(value) {
        const actions = [
            "focusWindow", "moveWindowToWorkspace", "closeWindow",
            "focusWorkspace", "moveWorkspaceToMonitor", "toggleFullscreen",
            "toggleFloating", "togglePinned", "toggleGroup", "exit"
        ];
        return root.exact(value, actions, [])
            && actions.every(action => typeof value[action] === "boolean");
    }

    function validMonitor(value) {
        return root.exact(value, ["id", "name", "width", "height", "scale", "focused"], [])
            && root.nonEmpty(value.id)
            && root.nonEmpty(value.name)
            && root.positiveU32(value.width)
            && root.positiveU32(value.height)
            && root.finitePositive(value.scale)
            && typeof value.focused === "boolean";
    }

    function validWorkspace(value) {
        return root.exact(value, ["id", "name", "monitorId", "focused"], [])
            && root.nonEmpty(value.id)
            && root.nonEmpty(value.name)
            && root.nonEmpty(value.monitorId)
            && typeof value.focused === "boolean";
    }

    function validMonitorCollection(value) {
        return root.validUniqueArray(value, 64, root.validMonitor, "id")
            && root.focusedCount(value) <= 1;
    }

    function validWorkspaceCollection(value, monitorIds) {
        if (!root.validUniqueArray(value, 1024, root.validWorkspace, "id")
                || root.focusedCount(value) > 1)
            return false;
        if (monitorIds) {
            for (const workspace of value) {
                if (!root.own(monitorIds, workspace.monitorId))
                    return false;
            }
        }
        return true;
    }

    function validWindow(value) {
        return root.exact(value, [
            "id", "title", "applicationId", "workspaceId", "focused",
            "fullscreen", "floating", "pinned", "grouped"
        ], [])
            && root.nonEmpty(value.id)
            && typeof value.title === "string"
            && root.nonEmpty(value.applicationId)
            && root.nonEmpty(value.workspaceId)
            && typeof value.focused === "boolean"
            && typeof value.fullscreen === "boolean"
            && typeof value.floating === "boolean"
            && typeof value.pinned === "boolean"
            && typeof value.grouped === "boolean";
    }

    function validWindowCollection(value, workspaceIds) {
        if (!root.validUniqueArray(value, 16384, root.validWindow, "id")
                || root.focusedCount(value) > 1)
            return false;
        if (workspaceIds) {
            for (const window of value) {
                if (!root.own(workspaceIds, window.workspaceId))
                    return false;
            }
        }
        return true;
    }

    function validHyprland(value) {
        if (!root.exact(value, ["actionCapabilities", "monitors", "workspaces", "windows"], [])
                || !root.validHyprlandActionCapabilities(value.actionCapabilities)
                || !root.validMonitorCollection(value.monitors))
            return false;
        const monitorIds = root.idSet(value.monitors);
        if (!root.validWorkspaceCollection(value.workspaces, monitorIds))
            return false;
        const workspaceIds = root.idSet(value.workspaces);
        return root.validWindowCollection(value.windows, workspaceIds);
    }

    function validHyprlandCapability(value) {
        return root.validCapability(value, root.validHyprland);
    }

    function validCompositor(value) {
        return root.exact(value, ["hyprland"], [])
            && root.validHyprlandCapability(value.hyprland);
    }

    function validNotificationAction(value) {
        return root.exact(value, ["id", "label", "state"], [])
            && root.nonEmpty(value.id)
            && root.nonEmpty(value.label)
            && root.oneOf(value.state, ["available", "expired"]);
    }

    function validNotification(value) {
        return root.exact(value, [
            "schemaVersion", "id", "applicationId", "summary", "body",
            "urgency", "createdAt", "read", "archived", "actions"
        ], ["timeoutMs"])
            && value.schemaVersion === 2
            && root.positiveInteger(value.id)
            && root.nonEmpty(value.applicationId)
            && root.nonEmpty(value.summary)
            && typeof value.body === "string"
            && root.oneOf(value.urgency, ["low", "normal", "critical"])
            && root.validTimestamp(value.createdAt)
            && (!root.own(value, "timeoutMs") || root.unsignedInteger(value.timeoutMs))
            && typeof value.read === "boolean"
            && typeof value.archived === "boolean"
            && root.validUniqueArray(value.actions, -1, root.validNotificationAction, "id");
    }

    function validNotifications(value) {
        return root.exact(value, ["availability", "dnd", "active"], [])
            && root.validProducerAvailability(value.availability)
            && typeof value.dnd === "boolean"
            && root.validUniqueArray(value.active, 500, root.validNotification, "id");
    }

    function validLauncherEntry(value) {
        return root.exact(value, ["id", "name", "icon"], [])
            && root.nonEmpty(value.id)
            && root.nonEmpty(value.name)
            && root.nonEmpty(value.icon);
    }

    function validLauncher(value) {
        return root.exact(value, ["availability", "entries"], [])
            && root.validProducerAvailability(value.availability)
            && root.validUniqueArray(value.entries, -1, root.validLauncherEntry, "id");
    }

    function validCalendarEvent(value) {
        return root.exact(value, ["id", "summary", "startsAt", "endsAt", "allDay", "sourceId"], ["location"])
            && root.nonEmpty(value.id)
            && root.nonEmpty(value.summary)
            && root.validTimestamp(value.startsAt)
            && root.validTimestamp(value.endsAt)
            && typeof value.allDay === "boolean"
            && root.nonEmpty(value.sourceId)
            && (!root.own(value, "location") || typeof value.location === "string");
    }

    function validCalendarError(value) {
        return root.exact(value, ["sourceId", "message"], [])
            && root.nonEmpty(value.sourceId)
            && root.nonEmpty(value.message);
    }

    function validCalendarData(value) {
        if (!root.exact(value, [
                    "schemaVersion", "providerId", "windowStart", "windowEnd",
                    "events", "sourceErrors"
                ], [])
                || value.schemaVersion !== 2
                || !root.nonEmpty(value.providerId)
                || !root.validTimestamp(value.windowStart)
                || !root.validTimestamp(value.windowEnd)
                || value.windowStart >= value.windowEnd
                || !root.validUniqueArray(value.events, -1, root.validCalendarEvent, "id")
                || !root.validArray(value.sourceErrors, -1, root.validCalendarError))
            return false;
        for (const event of value.events) {
            if (event.startsAt >= event.endsAt)
                return false;
        }
        return true;
    }

    function validCalendar(value) {
        return root.exact(value, ["availability", "snapshot"], [])
            && root.validProducerAvailability(value.availability)
            && root.validCalendarData(value.snapshot);
    }

    function validWeatherLocation(value) {
        return root.exact(value, ["displayName", "latitude", "longitude"], [])
            && root.nonEmpty(value.displayName)
            && Number.isFinite(value.latitude)
            && value.latitude >= -90 && value.latitude <= 90
            && Number.isFinite(value.longitude)
            && value.longitude >= -180 && value.longitude <= 180;
    }

    function validForecast(value) {
        return root.exact(value, ["at", "temperatureC", "symbol"], [])
            && root.validTimestamp(value.at)
            && Number.isFinite(value.temperatureC)
            && root.nonEmpty(value.symbol);
    }

    function validWeatherData(value) {
        if (!root.exact(value, [
                    "schemaVersion", "providerId", "location", "status",
                    "cache", "attribution", "forecast"
                ], ["diagnostic"])
                || value.schemaVersion !== 2
                || !root.nonEmpty(value.providerId)
                || !root.validWeatherLocation(value.location)
                || !root.oneOf(value.status, ["online", "offline", "error"])
                || !root.oneOf(value.cache, ["fresh", "stale", "missing"])
                || !root.nonEmpty(value.attribution)
                || !root.validArray(value.forecast, -1, root.validForecast))
            return false;
        if (value.status === "online" && root.own(value, "diagnostic"))
            return false;
        if (root.oneOf(value.status, ["offline", "error"])
                && (!root.own(value, "diagnostic") || !root.validDiagnostic(value.diagnostic)))
            return false;
        return true;
    }

    function validWeather(value) {
        return root.exact(value, ["availability", "snapshot"], [])
            && root.validProducerAvailability(value.availability)
            && root.validWeatherData(value.snapshot);
    }

    function validThemeColors(value) {
        return root.exact(value, [
            "background", "surface", "textPrimary", "textSecondary",
            "accent", "control"
        ], [])
            && root.validColor(value.background)
            && root.validColor(value.surface)
            && root.validColor(value.textPrimary)
            && root.validColor(value.textSecondary)
            && root.validColor(value.accent)
            && root.validColor(value.control);
    }

    function validTheme(value) {
        if (!root.exact(value, [
                    "schemaVersion", "id", "name", "origin", "appearance", "effects",
                    "reducedMotion", "opaqueFallback", "colors"
                ], [])
                || value.schemaVersion !== 1
                || !root.nonEmpty(value.id)
                || !root.nonEmpty(value.name)
                || !root.oneOf(value.origin, ["builtin", "user"])
                || !root.oneOf(value.appearance, ["dark", "light", "system"])
                || !root.oneOf(value.effects, ["full", "reduced", "none"])
                || typeof value.reducedMotion !== "boolean"
                || typeof value.opaqueFallback !== "boolean"
                || !root.validThemeColors(value.colors))
            return false;
        if (value.origin === "user" && !root.canonicalUuid(value.id))
            return false;
        const colors = value.colors;
        return root.contrastRatio(colors.textPrimary, colors.background) >= 4.5
            && root.contrastRatio(colors.textPrimary, colors.surface) >= 4.5
            && root.contrastRatio(colors.textSecondary, colors.background) >= 4.5
            && root.contrastRatio(colors.textSecondary, colors.surface) >= 4.5
            && root.contrastRatio(colors.accent, colors.background) >= 3.0
            && root.contrastRatio(colors.accent, colors.surface) >= 3.0
            && root.contrastRatio(colors.control, colors.background) >= 3.0
            && root.contrastRatio(colors.control, colors.surface) >= 3.0;
    }

    function parseColor(value) {
        return [
            parseInt(value.slice(1, 3), 16),
            parseInt(value.slice(3, 5), 16),
            parseInt(value.slice(5, 7), 16)
        ];
    }

    function luminanceChannel(value) {
        const normalizedValue = value / 255;
        return normalizedValue <= 0.04045
            ? normalizedValue / 12.92
            : Math.pow((normalizedValue + 0.055) / 1.055, 2.4);
    }

    function relativeLuminance(color) {
        const rgb = root.parseColor(color);
        return 0.2126 * root.luminanceChannel(rgb[0])
            + 0.7152 * root.luminanceChannel(rgb[1])
            + 0.0722 * root.luminanceChannel(rgb[2]);
    }

    function contrastRatio(foreground, background) {
        const foregroundLuminance = root.relativeLuminance(foreground);
        const backgroundLuminance = root.relativeLuminance(background);
        const lighter = Math.max(foregroundLuminance, backgroundLuminance);
        const darker = Math.min(foregroundLuminance, backgroundLuminance);
        return (lighter + 0.05) / (darker + 0.05);
    }

    function validAppearance(value) {
        return root.exact(value, ["availability", "theme", "wallpaperId"], [])
            && root.validProducerAvailability(value.availability)
            && root.validTheme(value.theme)
            && root.nonEmpty(value.wallpaperId);
    }

    function validResourceSample(value) {
        return root.exact(value, ["id", "cpuUsage", "memoryUsage", "loadOne"], [])
            && root.nonEmpty(value.id)
            && root.normalized(value.cpuUsage)
            && root.normalized(value.memoryUsage)
            && Number.isFinite(value.loadOne)
            && value.loadOne >= 0;
    }

    function validResources(value) {
        return root.exact(value, ["availability", "samples"], [])
            && root.validProducerAvailability(value.availability)
            && root.validUniqueArray(value.samples, -1, root.validResourceSample, "id");
    }

    function validMenuNode(value) {
        return root.validMenuNodeRecord(value);
    }

    function validMenuNodeRecord(value) {
        return root.exact(value, ["id", "label", "enabled", "children"], [])
            && root.nonEmpty(value.id)
            && root.nonEmpty(value.label)
            && typeof value.enabled === "boolean"
            && Array.isArray(value.children)
            && value.children.length <= 65535;
    }

    function validMenuTree(value, aggregate) {
        const menuIds = Object.create(null);
        const pending = [{"node": value, "depth": 1}];
        while (pending.length > 0) {
            const frame = pending.pop();
            if (frame.depth > root.maximumMenuDepth)
                return false;
            if (!root.validMenuNodeRecord(frame.node))
                return false;
            ++aggregate.count;
            if (aggregate.count > root.maximumMenuNodes)
                return false;
            if (root.own(menuIds, frame.node.id))
                return false;
            menuIds[frame.node.id] = true;
            for (const child of frame.node.children)
                pending.push({"node": child, "depth": frame.depth + 1});
        }
        return true;
    }

    function validTrayItem(value) {
        return root.validTrayItemRecord(value)
            && root.validMenuTree(value.menu, {"count": 0});
    }

    function validTrayItemRecord(value) {
        return root.exact(value, ["id", "title", "menu"], [])
            && root.nonEmpty(value.id)
            && root.nonEmpty(value.title);
    }

    function validTrayItems(value) {
        if (!Array.isArray(value) || value.length > 1024)
            return false;
        const trayIds = Object.create(null);
        const aggregate = {"count": 0};
        for (const item of value) {
            if (!root.validTrayItemRecord(item)
                    || root.own(trayIds, item.id)
                    || !root.validMenuTree(item.menu, aggregate))
                return false;
            trayIds[item.id] = true;
        }
        return true;
    }

    function validClipboardEntry(value) {
        return root.exact(value, ["id", "preview", "mimeType", "byteLength"], [])
            && root.nonEmpty(value.id)
            && typeof value.preview === "string"
            && root.nonEmpty(value.mimeType)
            && root.unsignedInteger(value.byteLength);
    }

    function validRecording(value) {
        if (root.exact(value, ["status"], []) && value.status === "inactive")
            return true;
        return root.exact(value, ["status", "recordingId", "outputId"], [])
            && root.oneOf(value.status, ["recording", "paused"])
            && root.nonEmpty(value.recordingId)
            && root.nonEmpty(value.outputId);
    }

    function validTrayItemsCapability(value) {
        return root.validCapability(value, root.validTrayItems);
    }

    function validClipboardEntriesCapability(value) {
        return root.validCapability(value, function(data) {
            return root.validUniqueArray(data, 500, root.validClipboardEntry, "id");
        });
    }

    function validRecordingCapability(value) {
        return root.validCapability(value, root.validRecording);
    }

    function validBooleanCapability(value) {
        return root.validCapability(value, function(data) {
            return typeof data === "boolean";
        });
    }

    function validUtilities(value) {
        return root.exact(value, [
            "trayItems", "clipboardEntries", "recording", "idleInhibited",
            "gameMode", "screenshot", "colorPicker"
        ], [])
            && root.validTrayItemsCapability(value.trayItems)
            && root.validClipboardEntriesCapability(value.clipboardEntries)
            && root.validRecordingCapability(value.recording)
            && root.validBooleanCapability(value.idleInhibited)
            && root.validBooleanCapability(value.gameMode)
            && root.validProducerAvailability(value.screenshot)
            && root.validProducerAvailability(value.colorPicker);
    }

    function validSnapshot(value) {
        return root.exact(value, root.topics, [])
            && root.validSystem(value.system)
            && root.validCompositor(value.compositor)
            && root.validNotifications(value.notifications)
            && root.validLauncher(value.launcher)
            && root.validCalendar(value.calendar)
            && root.validWeather(value.weather)
            && root.validAppearance(value.appearance)
            && root.validResources(value.resources)
            && root.validUtilities(value.utilities);
    }

    function validSystemUpdate(update) {
        if (!root.exact(update, ["domain", "data"], []))
            return false;
        switch (update.domain) {
        case "network":
            return root.validNetworkCapability(update.data);
        case "bluetooth":
            return root.validBluetoothCapability(update.data);
        case "audio":
            return root.validAudioCapability(update.data);
        case "media":
            return root.validMediaCapability(update.data);
        case "battery":
            return root.validBatteryCapability(update.data);
        case "brightness":
            return root.validBrightnessCapability(update.data);
        case "nightLight":
            return root.validNightLightCapability(update.data);
        case "power":
            return root.validPowerCapability(update.data);
        case "osd":
            return root.validOsdCapability(update.data);
        case "lock":
            return root.validLockCapability(update.data);
        default:
            return false;
        }
    }

    function validCompositorUpdate(update) {
        if (!root.exact(update, ["domain", "data"], []))
            return false;
        switch (update.domain) {
        case "hyprland":
            return root.validHyprlandCapability(update.data);
        case "monitors":
            return root.validMonitorCollection(update.data);
        case "workspaces":
            return root.validWorkspaceCollection(update.data);
        case "windows":
            return root.validWindowCollection(update.data);
        default:
            return false;
        }
    }

    function validUtilityUpdate(update) {
        if (!root.exact(update, ["domain", "data"], []))
            return false;
        switch (update.domain) {
        case "trayItems":
            return root.validTrayItemsCapability(update.data);
        case "clipboardEntries":
            return root.validClipboardEntriesCapability(update.data);
        case "recording":
            return root.validRecordingCapability(update.data);
        case "idleInhibited":
            return root.validBooleanCapability(update.data);
        case "gameMode":
            return root.validBooleanCapability(update.data);
        case "screenshot":
        case "colorPicker":
            return root.validProducerAvailability(update.data);
        default:
            return false;
        }
    }

    function validDomainUpdate(update) {
        if (!root.exact(update, ["topic", "update"], []))
            return false;
        switch (update.topic) {
        case "system":
            return root.validSystemUpdate(update.update);
        case "compositor":
            return root.validCompositorUpdate(update.update);
        case "notifications":
            return root.validNotifications(update.update);
        case "launcher":
            return root.validLauncher(update.update);
        case "calendar":
            return root.validCalendar(update.update);
        case "weather":
            return root.validWeather(update.update);
        case "appearance":
            return root.validAppearance(update.update);
        case "resources":
            return root.validResources(update.update);
        case "utilities":
            return root.validUtilityUpdate(update.update);
        default:
            return false;
        }
    }

    function defaultHyprlandActionCapabilities() {
        return Object.freeze({
            "focusWindow": false,
            "moveWindowToWorkspace": false,
            "closeWindow": false,
            "focusWorkspace": false,
            "moveWorkspaceToMonitor": false,
            "toggleFullscreen": false,
            "toggleFloating": false,
            "togglePinned": false,
            "toggleGroup": false,
            "exit": false
        });
    }

    function applyCompositorUpdate(next, update) {
        const compositor = Object.assign({}, next.compositor || {});
        if (update.domain === "hyprland") {
            compositor.hyprland = update.data;
            next.compositor = Object.freeze(compositor);
            return;
        }

        const existingCapability = compositor.hyprland || {};
        const existingData = existingCapability.status === "available"
            && existingCapability.data && typeof existingCapability.data === "object"
            && !Array.isArray(existingCapability.data) ? existingCapability.data : {};
        const data = Object.assign({
            "actionCapabilities": root.defaultHyprlandActionCapabilities(),
            "monitors": [],
            "workspaces": [],
            "windows": []
        }, existingData);
        data[update.domain] = update.data;
        compositor.hyprland = Object.freeze({"status": "available", "data": Object.freeze(data)});
        next.compositor = Object.freeze(compositor);
    }

    function validCause(cause) {
        if (!cause || typeof cause !== "object" || Array.isArray(cause))
            return false;
        if (cause.kind === "request")
            return root.exact(cause, ["kind", "requestId"], [])
                && root.canonicalUuid(cause.requestId);
        return root.exact(cause, ["kind"], [])
            && ["external", "replay", "lifecycle"].indexOf(cause.kind) >= 0;
    }

    function beginConnection() {
        root.connectionState = "connecting";
        root.diagnostic = "Waiting for full desktop snapshot";
        root.snapshotReceived = false;
    }

    function disconnected(message) {
        root.connectionState = "offline";
        root.diagnostic = message || "sleepy-sessiond desktop stream disconnected";
        root.snapshotReceived = false;
    }

    function fail(message) {
        root.connectionState = "error";
        root.diagnostic = message;
        root.protocolError(message);
        return false;
    }

    function boundedRetryDelay(attempt) {
        const floor = Math.max(1, root.minimumRetryMs);
        const ceiling = Math.max(floor, root.maximumRetryMs);
        const raw = floor * Math.pow(2, Math.max(0, attempt));
        return Math.min(ceiling, raw);
    }

    function rememberRequest(requestId, generation) {
        if (!root.canonicalUuid(requestId))
            return;
        const observed = Object.assign({}, root.observedRequestIds);
        let order = root.observedRequestOrder.slice();
        if (!root.own(observed, requestId))
            order.push(requestId);
        observed[requestId] = generation;
        const maximum = Math.max(1, root.maximumObservedRequests);
        while (order.length > maximum) {
            const evicted = order.shift();
            delete observed[evicted];
        }
        root.observedRequestIds = Object.freeze(observed);
        root.observedRequestOrder = Object.freeze(order);
    }

    function clearObservedRequests() {
        root.observedRequestIds = Object.freeze({});
        root.observedRequestOrder = Object.freeze([]);
    }

    function domain(name) {
        return root.snapshot && root.own(root.snapshot, name) ? root.snapshot[name] : null;
    }

    function capability(id) {
        const system = root.domain("system") || {};
        let record = system[id] || null;
        if (!record && id === "powerProfile")
            record = system.power || null;
        if (!record && id === "niri") {
            const compositor = root.domain("compositor") || {};
            record = compositor.hyprland || null;
        }
        if (!record || typeof record !== "object")
            return Object.freeze({
                "id": id, "status": "unsupported", "available": false,
                "value": null, "diagnostic": "Capability has not reported"
            });
        if (record.status === "available")
            return Object.freeze({
                "id": id, "status": "available", "available": true,
                "value": Object.freeze({"type": id, "data": root.legacyCapabilityData(id, record.data)}),
                "diagnostic": ""
            });
        return Object.freeze({
            "id": id, "status": record.status || "unavailable",
            "available": false, "value": null,
            "diagnostic": record.diagnostic && record.diagnostic.message
                          ? record.diagnostic.message : (record.status || "unavailable")
        });
    }

    function legacyCapabilityData(id, data) {
        data = data || {};
        switch (id) {
        case "network": {
            const connections = Array.isArray(data.connections) ? data.connections : [];
            const active = connections.find(item => item.connected);
            return {
                "wifiEnabled": Boolean(data.wifiEnabled),
                "ethernetConnected": connections.some(item => item.kind === "ethernet" && item.connected),
                "connectivity": active ? "full" : "none",
                "activeConnectionId": active ? active.id : ""
            };
        }
        case "bluetooth":
            return {
                "powered": Boolean(data.powered),
                "connectedDeviceIds": Array.isArray(data.devices)
                    ? data.devices.filter(item => item.connected).map(item => item.id) : []
            };
        case "audio": {
            const nodes = Array.isArray(data.nodes) ? data.nodes : [];
            const output = nodes.find(item => item.kind === "output" && item.isDefault)
                         || nodes.find(item => item.kind === "output") || {};
            const input = nodes.find(item => item.kind === "input" && item.isDefault)
                        || nodes.find(item => item.kind === "input") || {};
            return {
                "outputLevel": Number.isFinite(output.volume) ? output.volume : 0,
                "outputMuted": Boolean(output.muted),
                "inputLevel": Number.isFinite(input.volume) ? input.volume : 0,
                "inputMuted": Boolean(input.muted),
                "defaultOutputId": output.id || ""
            };
        }
        case "battery":
            return {
                "percentage": Math.round((Number.isFinite(data.level) ? data.level : 0) * 100),
                "charging": Boolean(data.charging),
                "secondsRemaining": Number.isSafeInteger(data.secondsRemaining)
                                    ? data.secondsRemaining : 0
            };
        case "brightness":
            return {"level": Number.isFinite(data.level) ? data.level : 0};
        case "powerProfile":
            return {
                "active": data.activeProfile || "balanced",
                "available": Array.isArray(data.availableProfiles)
                             ? data.availableProfiles : ["balanced"]
            };
        case "media": {
            const player = Array.isArray(data.players) && data.players.length ? data.players[0] : {};
            return {
                "playerId": player.id || "none",
                "title": player.title || "",
                "artist": player.artist || "",
                "playing": Boolean(player.playing)
            };
        }
        case "nightLight":
            return {"enabled": Boolean(data.enabled)};
        case "niri": {
            const monitors = Array.isArray(data.monitors) ? data.monitors : [];
            const workspaces = Array.isArray(data.workspaces) ? data.workspaces : [];
            const windows = Array.isArray(data.windows) ? data.windows : [];
            return {
                "outputIds": monitors.map(item => item.id || item.name).filter(Boolean),
                "workspaceIds": workspaces.map(item => parseInt(item.id, 10)).filter(Number.isSafeInteger),
                "windowIds": windows.map((_item, index) => index + 1)
            };
        }
        case "resources": {
            const samples = Array.isArray(data.samples) ? data.samples : [];
            const sample = samples.length ? samples[0] : {};
            return {
                "cpuUsage": Number.isFinite(sample.cpuUsage) ? sample.cpuUsage : 0,
                "memoryUsage": Number.isFinite(sample.memoryUsage) ? sample.memoryUsage : 0,
                "loadOne": Number.isFinite(sample.loadOne) ? sample.loadOne : 0
            };
        }
        default:
            return data;
        }
    }

    function publishDomainUpdate(update) {
        const next = Object.assign({}, root.snapshot);
        if (update.topic === "compositor") {
            root.applyCompositorUpdate(next, update.update);
        } else if (root.exact(update.update, ["domain", "data"], [])) {
            const topic = Object.assign({}, next[update.topic] || {});
            topic[update.update.domain] = update.update.data;
            next[update.topic] = Object.freeze(topic);
        } else {
            next[update.topic] = update.update;
        }
        root.snapshot = Object.freeze(next);
        return true;
    }

    function applyDomainUpdate(update) {
        return root.validDomainUpdate(update) && root.publishDomainUpdate(update);
    }

    function validCommandResult(result) {
        if (!result || result.schemaVersion !== 3 || !root.canonicalUuid(result.requestId)
                || !root.positiveInteger(result.generation)
                || ["succeeded", "failed"].indexOf(result.status) < 0)
            return false;
        if (result.status === "succeeded")
            return root.exact(result, ["schemaVersion", "requestId", "generation", "status"], []);
        return root.exact(result, ["schemaVersion", "requestId", "generation", "status", "diagnostic"], [])
            && root.exact(result.diagnostic, ["message"], [])
            && root.nonEmpty(result.diagnostic.message);
    }

    function validCommandResultEnvelope(envelope) {
        const result = envelope.payload.data;
        return root.validCommandResult(result)
            && envelope.cause.kind === "request"
            && envelope.cause.requestId === result.requestId
            && envelope.generation === result.generation;
    }

    function validPayload(envelope) {
        const payload = envelope.payload;
        if (!root.exact(payload, ["type", "data"], [])
                || ["fullSnapshot", "domainUpdate", "commandResult"].indexOf(payload.type) < 0)
            return false;
        switch (payload.type) {
        case "fullSnapshot":
            return root.validSnapshot(payload.data);
        case "domainUpdate":
            return root.validDomainUpdate(payload.data);
        case "commandResult":
            return root.validCommandResultEnvelope(envelope);
        default:
            return false;
        }
    }

    function applyPayload(envelope) {
        const payload = envelope.payload;
        switch (payload.type) {
        case "fullSnapshot":
            root.snapshot = Object.freeze(Object.assign({}, payload.data));
            return true;
        case "domainUpdate":
            return root.publishDomainUpdate(payload.data);
        case "commandResult":
            root.lastCommandResult = Object.freeze(Object.assign({}, payload.data));
            root.rememberRequest(payload.data.requestId, payload.data.generation);
            root.commandResultAccepted(root.lastCommandResult);
            return true;
        default:
            return false;
        }
    }

    function acceptEnvelope(envelope) {
        if (!root.exact(envelope,
                        ["schemaVersion", "generation", "eventId", "emittedAt", "cause", "payload"], [])
                || envelope.schemaVersion !== 3
                || !root.positiveInteger(envelope.generation)
                || !root.canonicalUuid(envelope.eventId)
                || !root.validTimestamp(envelope.emittedAt)
                || !root.validCause(envelope.cause))
            return root.fail("Invalid desktop event envelope");
        if (!root.snapshotReceived && envelope.payload.type !== "fullSnapshot")
            return root.fail("First desktop event was not a full snapshot");
        if (root.snapshotReceived && envelope.generation <= root.generation)
            return root.fail("Desktop event generation did not increase");
        if (!root.snapshotReceived && envelope.generation < root.generation)
            return root.fail("Replay generation regressed");
        if (!root.validPayload(envelope))
            return root.fail("Invalid desktop event payload");

        if (envelope.generation !== root.generation) {
            root.generation = envelope.generation;
            root.clearObservedRequests();
            root.daemonGenerationChanged(root.generation);
        }
        if (envelope.cause.kind === "request")
            root.rememberRequest(envelope.cause.requestId, envelope.generation);
        if (!root.applyPayload(envelope))
            return root.fail("Invalid desktop event payload");
        root.snapshotReceived = true;
        root.connectionState = "ready";
        root.diagnostic = "";
        root.eventAccepted(Object.freeze(envelope));
        return true;
    }

    function acceptLine(line) {
        let envelope;
        try {
            envelope = JSON.parse(String(line));
        } catch (error) {
            return root.fail("Malformed desktop event JSON");
        }
        return root.acceptEnvelope(envelope);
    }

    function acceptCommandResult(result) {
        if (!root.validCommandResult(result))
            return false;
        root.lastCommandResult = Object.freeze(Object.assign({}, result));
        root.rememberRequest(result.requestId, result.generation);
        root.commandResultAccepted(root.lastCommandResult);
        return true;
    }
}
