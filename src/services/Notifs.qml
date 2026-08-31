// SPDX-License-Identifier: GPL-3.0-only
// Modified for Sleepy on 2026-08-31: notifications are daemon-published.

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Sleepy
import Sleepy.Config
import qs.components.misc
import qs.services

Singleton {
    id: root

    readonly property var notificationsState: DesktopModel.notifications || ({})
    property list<NotifData> list: []
    readonly property list<NotifData> notClosed: list.filter(n => !n.closed)
    readonly property list<NotifData> popups: list.filter(n => n.popup)
    property bool dnd: Boolean(notificationsState.dnd)
    property bool loaded: true
    property bool syncingDnd: false

    function records(): list<var> {
        return notificationsState.active || notificationsState.items || notificationsState.notifications || [];
    }

    function hasFullscreen(): bool {
        return Hypr.toplevels.values.some(window => window.lastIpcObject?.fullscreen > 1);
    }

    function shouldShowPopup(): bool {
        if (root.dnd || ShellState.anySidebarOpen())
            return false;
        if (GlobalConfig.notifs.fullscreen === NotifsFullscreen.Off && root.hasFullscreen())
            return false;
        return true;
    }

    function actionRecord(notificationId: string, action: var): var {
        const identifier = action.identifier || action.id || "";
        return {
            "identifier": identifier,
            "text": action.text || action.label || identifier,
            "invoke": function() {
                return CommandClient.notification({
                    "type": "invoke",
                    "data": {"notificationId": notificationId, "actionId": identifier}
                });
            }
        };
    }

    function rebuildList(): void {
        for (const existing of root.list)
            existing.destroy();

        const next = [];
        for (const record of root.records()) {
            const notificationId = String(record.id || record.notificationId || "");
            const createdAt = Date.parse(record.createdAt || record.time || "");
            next.push(notifComp.createObject(root, {
                "popup": record.popup ?? root.shouldShowPopup(),
                "closed": Boolean(record.closed || record.archived),
                "time": Number.isNaN(createdAt) ? new Date() : new Date(createdAt),
                "notificationId": notificationId,
                "summary": record.summary || "",
                "body": record.body || "",
                "appIcon": record.appIcon || record.applicationIcon || "",
                "appName": record.appName || record.applicationId || "",
                "image": record.image || "",
                "hints": record.hints || {},
                "expireTimeout": record.expireTimeout ?? record.timeoutMs ?? GlobalConfig.notifs.defaultExpireTimeout,
                "urgency": record.urgency ?? 1,
                "resident": Boolean(record.resident),
                "hasActionIcons": Boolean(record.hasActionIcons),
                "actions": (record.actions || []).map(action => root.actionRecord(notificationId, action))
            }));
        }
        root.list = next;
    }

    function syncDnd(): void {
        const next = Boolean(root.notificationsState.dnd);
        if (root.dnd === next)
            return;
        root.syncingDnd = true;
        root.dnd = next;
        root.syncingDnd = false;
    }

    function dismiss(notificationId: string): bool {
        root.list = root.list.filter(notif => notif.notificationId !== notificationId);
        return CommandClient.notification({
            "type": "dismiss",
            "data": {"notificationId": notificationId}
        });
    }

    function clear(): void {
        for (const notif of root.list.slice())
            notif.close();
    }

    function setDnd(enabled: bool): bool {
        return CommandClient.notification({
            "type": "setDnd",
            "data": {"enabled": Boolean(enabled)}
        });
    }

    function toggleDnd(): bool {
        return root.setDnd(!root.dnd);
    }

    function enableDnd(): bool {
        return root.setDnd(true);
    }

    function disableDnd(): bool {
        return root.setDnd(false);
    }

    onNotificationsStateChanged: {
        root.syncDnd();
        root.rebuildList();
    }

    onDndChanged: {
        if (!root.syncingDnd)
            root.setDnd(root.dnd);
        if (!GlobalConfig.utilities.toasts.dndChanged)
            return;
        if (root.dnd)
            Toaster.toast(qsTr("Do not disturb enabled"), qsTr("Popup notifications are now disabled"), "do_not_disturb_on");
        else
            Toaster.toast(qsTr("Do not disturb disabled"), qsTr("Popup notifications are now enabled"), "do_not_disturb_off");
    }

    Component.onCompleted: {
        root.syncDnd();
        root.rebuildList();
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "clearNotifs"
        description: "Clear all notifications"
        onPressed: root.clear()
    }

    IpcHandler {
        function clear(): void {
            root.clear();
        }

        function isDndEnabled(): bool {
            return root.dnd;
        }

        function toggleDnd(): void {
            root.toggleDnd();
        }

        function enableDnd(): void {
            root.enableDnd();
        }

        function disableDnd(): void {
            root.disableDnd();
        }

        target: "notifs"
    }

    Component {
        id: notifComp

        NotifData {}
    }
}
