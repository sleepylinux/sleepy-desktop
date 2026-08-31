// SPDX-License-Identifier: GPL-3.0-only
// Derived from Caelestia v2.4.0 launcher and notification drawer behavior for Sleepy.

import QtQuick 6.0
import "../services/DesktopCommands.js" as DesktopCommands

QtObject {
    id: root

    required property var desktopModel
    required property var commandClient
    required property string outputId
    property bool surfaceAllowed: true
    property string activeSurface: ""
    property string launcherSearchText: ""
    property var returnFocusItem: null

    readonly property bool busy: Boolean(root.commandClient?.busy ?? false)
    readonly property bool overlayOpen: root.activeSurface.length > 0
    readonly property bool launcherAvailable: root.desktopModel.producerAvailable("launcher")
    readonly property string launcherDiagnostic:
        root.desktopModel.producerDiagnostic("launcher") || "Launcher unavailable"
    readonly property bool notificationsAvailable:
        root.desktopModel.producerAvailable("notifications")
    readonly property string notificationsDiagnostic:
        root.desktopModel.producerDiagnostic("notifications") || "Notifications unavailable"
    readonly property bool launcherCalculatorSupported: false
    readonly property bool launcherCommandModeSupported: false
    readonly property bool launcherActionsSupported: false
    readonly property var launcherEntries: root.desktopModel.launcherEntries
    readonly property var filteredLauncherEntries: {
        void(root.desktopModel.launcherEntries);
        const query = root.launcherSearchText.trim().toLocaleLowerCase();
        const rows = root.desktopModel.launcherEntries.filter(entry => {
            if (!query.length)
                return true;
            return String(entry.name).toLocaleLowerCase().indexOf(query) >= 0
                || String(entry.id).toLocaleLowerCase().indexOf(query) >= 0;
        });
        return rows.slice().sort((left, right) =>
            String(left.name).localeCompare(String(right.name)));
    }
    readonly property var notificationItems: root.desktopModel.notificationItems
    readonly property var toastItems: {
        void(root.desktopModel.notificationItems);
        if (!root.notificationsAvailable || root.dndEnabled)
            return [];
        return root.desktopModel.notificationItems.filter(
            item => !item.read && !item.archived);
    }
    readonly property bool dndEnabled:
        root.notificationsAvailable && Boolean(root.desktopModel.notifications?.dnd ?? false)
    readonly property bool overlayPresentationVisible:
        root.overlayOpen || root.toastItems.length > 0

    function validSurface(surfaceId) {
        return surfaceId === "launcher" || surfaceId === "notifications";
    }

    function openSurface(surfaceId, focusItem) {
        if (!root.surfaceAllowed || !root.validSurface(surfaceId))
            return false;
        if (focusItem && typeof focusItem.forceActiveFocus === "function")
            root.returnFocusItem = focusItem;
        root.activeSurface = surfaceId;
        return true;
    }

    function toggleSurface(surfaceId, focusItem) {
        if (root.activeSurface === surfaceId) {
            root.closeSurface();
            return true;
        }
        return root.openSurface(surfaceId, focusItem);
    }

    function closeSurface() {
        const focusItem = root.returnFocusItem;
        root.activeSurface = "";
        root.launcherSearchText = "";
        root.returnFocusItem = null;
        if (focusItem && typeof focusItem.forceActiveFocus === "function") {
            Qt.callLater(function() {
                if (focusItem.enabled)
                    focusItem.forceActiveFocus();
            });
        }
    }

    function launcherEntry(desktopId) {
        if (typeof desktopId !== "string")
            return null;
        return root.launcherEntries.find(entry => entry.id === desktopId) || null;
    }

    function launchEntry(desktopId) {
        if (!root.launcherAvailable || root.busy || !root.launcherEntry(desktopId))
            return false;
        const command = DesktopCommands.launcherLaunch(desktopId, [], "");
        return command ? root.commandClient.launcher(command) : false;
    }

    // Strict desktop-v3 launcher rows do not expose action IDs. Keep the
    // affordance unavailable until a confirmed protocol row can authorize it.
    function launchAction(_desktopId, _actionId) {
        return false;
    }

    function notificationById(notificationId) {
        if (typeof notificationId !== "number" || !Number.isInteger(notificationId)
                || notificationId <= 0)
            return null;
        return root.notificationItems.find(item => item.id === notificationId) || null;
    }

    function setDnd(enabled) {
        if (!root.notificationsAvailable || root.busy
                || typeof enabled !== "boolean")
            return false;
        const command = DesktopCommands.notificationSetDnd(enabled);
        return command ? root.commandClient.notification(command) : false;
    }

    function archiveNotification(notificationId) {
        const item = root.notificationById(notificationId);
        if (!root.notificationsAvailable || root.busy || !item || item.archived)
            return false;
        const command = DesktopCommands.notificationArchive(notificationId);
        return command ? root.commandClient.notification(command) : false;
    }

    function invokeNotificationAction(notificationId, actionId) {
        const item = root.notificationById(notificationId);
        if (typeof actionId !== "string")
            return false;
        const action = item?.actions?.find(candidate =>
            candidate.id === actionId && candidate.state === "available") || null;
        if (!root.notificationsAvailable || root.busy || !action)
            return false;
        const command = DesktopCommands.notificationInvokeAction(
            notificationId, actionId);
        return command ? root.commandClient.notification(command) : false;
    }

    onSurfaceAllowedChanged: {
        if (!root.surfaceAllowed)
            root.closeSurface();
    }
}
