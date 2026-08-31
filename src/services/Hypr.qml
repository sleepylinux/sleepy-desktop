// SPDX-License-Identifier: GPL-3.0-only
// Modified for Sleepy on 2026-08-31: compositor state is daemon-published.

pragma Singleton

import QtQuick
import Quickshell
import "DesktopCommands.js" as DesktopCommands

Singleton {
    id: root

    readonly property var compositorCapability: DesktopModel.capabilityData(
        "compositor", "hyprland",
        {"monitors": [], "workspaces": [], "windows": [], "focusedMonitorId": "",
         "focusedWorkspaceId": "", "focusedWindowId": "", "keyboard": {},
         "options": {}, "devices": []})
    readonly property list<var> monitorList: (compositorCapability.monitors || []).map(monitorRecord)
    readonly property list<var> workspaceList: (compositorCapability.workspaces || []).map(workspaceRecord)
    readonly property list<var> windowList: (compositorCapability.windows || []).map(windowRecord)
    readonly property alias monitors: monitorsModel
    readonly property alias workspaces: workspacesModel
    readonly property alias toplevels: toplevelsModel
    readonly property bool usingLua: false
    readonly property var focusedMonitor: monitorList.find(item => item.id === compositorCapability.focusedMonitorId)
                                          || (monitorList.length ? monitorList[0] : null)
    readonly property var focusedWorkspace: workspaceList.find(item => item.id === compositorCapability.focusedWorkspaceId)
                                            || (workspaceList.length ? workspaceList[0] : null)
    readonly property var activeToplevel: windowList.find(item => item.id === compositorCapability.focusedWindowId)
                                           || null
    readonly property int activeWsId: Number.parseInt(focusedWorkspace?.id || "1", 10) || 1
    readonly property var keyboard: compositorCapability.keyboard || {}
    readonly property bool capsLock: Boolean(keyboard.capsLock)
    readonly property bool numLock: Boolean(keyboard.numLock)
    readonly property string defaultKbLayout: keyboard.defaultLayout || keyboard.layout || ""
    readonly property string kbLayoutFull: keyboard.layout || defaultKbLayout
    readonly property string kbLayout: kbLayoutFull.split(",")[0] || ""
    readonly property var kbMap: keyboard.layoutMap || {}
    readonly property var options: compositorCapability.options || {}
    readonly property var devices: compositorCapability.devices || []
    readonly property string lastSpecialWorkspace: compositorCapability.lastSpecialWorkspace || ""
    readonly property alias extras: extrasModel

    signal configReloaded

    function windowRecord(window: var): var {
        const workspaceId = String(window.workspaceId || window.workspace?.id || "");
        const rawWorkspace = (root.compositorCapability.workspaces || [])
            .find(item => String(item.id || item.name || "") === workspaceId) || null;
        const workspace = rawWorkspace ? Object.assign({
            "id": workspaceId,
            "name": rawWorkspace.name || workspaceId
        }, rawWorkspace) : null;
        return Object.assign({
            "id": window.id || window.address || "",
            "address": window.address || window.id || "",
            "title": window.title || "",
            "appId": window.appId || window.class || "",
            "workspace": workspace,
            "wayland": null,
            "lastIpcObject": {
                "address": window.address || window.id || "",
                "class": window.class || window.appId || "",
                "fullscreen": window.fullscreen ? 2 : 0,
                "floating": Boolean(window.floating),
                "pinned": Boolean(window.pinned)
            }
        }, window);
    }

    function workspaceRecord(workspace: var): var {
        const id = String(workspace.id || workspace.name || "");
        const values = (root.compositorCapability.windows || [])
            .filter(window => String(window.workspaceId || window.workspace?.id || "") === id)
            .map(windowRecord);
        return Object.assign({
            "id": id,
            "name": workspace.name || id,
            "monitor": root.monitorList.find(monitor => monitor.id === workspace.monitorId) || null,
            "toplevels": {"values": values},
            "lastIpcObject": {
                "id": Number.parseInt(id, 10) || 0,
                "name": workspace.name || id,
                "specialWorkspace": workspace.specialWorkspace || null
            }
        }, workspace);
    }

    function monitorRecord(monitor: var): var {
        return Object.assign({
            "id": monitor.id || monitor.name || "",
            "name": monitor.name || monitor.id || "",
            "lastIpcObject": {
                "name": monitor.name || monitor.id || "",
                "specialWorkspace": monitor.specialWorkspace || null
            }
        }, monitor);
    }

    function dispatch(_request: var): bool {
        return false;
    }

    function cycleSpecialWorkspace(direction: int): bool {
        void(direction);
        return false;
    }

    function monitorNames(): list<string> {
        return root.monitorList.map(monitor => monitor.name || monitor.id).filter(name => name && name.length);
    }

    function monitorFor(screen: var): var {
        if (!screen)
            return root.focusedMonitor;
        const name = screen.name || screen.model || String(screen);
        return root.monitorList.find(monitor => monitor.name === name || monitor.id === name)
            || root.focusedMonitor;
    }

    function toplevelsForWs(workspaceId: int): list<var> {
        return root.windowList.filter(window =>
            Number.parseInt(window.workspaceId || window.workspace?.id || "0", 10) === workspaceId);
    }

    function isToplevelIgnored(toplevel: var): bool {
        return Boolean(toplevel?.ignored);
    }

    function reloadDynamicConfs(): bool {
        return false;
    }

    function refreshDevices(): bool {
        return false;
    }

    QtObject {
        id: monitorsModel

        readonly property list<var> values: root.monitorList
    }

    QtObject {
        id: workspacesModel

        readonly property list<var> values: root.workspaceList
    }

    QtObject {
        id: toplevelsModel

        readonly property list<var> values: root.windowList
    }

    QtObject {
        id: extrasModel

        readonly property var options: root.options
        readonly property var devices: root.devices

        function applyOptions(_updates: var): bool {
            return false;
        }

        function message(messageName: string): bool {
            void(messageName);
            return false;
        }
    }
}
