// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0

QtObject {
    id: root
    property var items: Object.freeze([])
    property bool dnd: false
    readonly property int unreadCount: items.filter(function(item) { return item.unread; }).length

    function plain(value) { return typeof value === "string" ? value : ""; }
    function acceptDocument(document) {
        if (!document || !Number.isSafeInteger(document.id) || document.id <= 0
                || typeof document.application !== "string"
                || typeof document.summary !== "string" || typeof document.body !== "string")
            return false;
        const next = root.items.filter(function(item) { return item.id !== document.id; });
        next.unshift(Object.freeze({
            "id": document.id,
            "application": root.plain(document.application),
            "summary": root.plain(document.summary),
            "body": root.plain(document.body),
            "urgency": document.urgency || "normal",
            "unread": document.unread !== false,
            "actions": Array.isArray(document.actions) ? document.actions.map(function(action) {
                return Object.freeze({"id": root.plain(action.id), "label": root.plain(action.label),
                                      "state": action.state || "expired"});
            }) : []
        }));
        root.items = Object.freeze(next.slice(0, 500));
        return true;
    }
    function acceptEvent(event) {
        if (!event || !Number.isSafeInteger(event.notificationId)) return false;
        if (event.change === "archived") {
            root.items = Object.freeze(root.items.filter(function(item) {
                return item.id !== event.notificationId;
            }));
            return true;
        }
        // Strict event v2 only carries the server-owned id and change. Keep the
        // state truthful until a typed history read contract is available.
        if (event.change === "added" || event.change === "updated") {
            const exists = root.items.some(function(item) { return item.id === event.notificationId; });
            if (!exists) root.items = Object.freeze(root.items.concat([Object.freeze({
                "id": event.notificationId, "application": "", "summary": "Notification",
                "body": "History details unavailable from wire v2", "urgency": "normal",
                "unread": true, "actions": []
            })]));
            return true;
        }
        if (event.change === "actionExpired") return true;
        return false;
    }
    function markAllRead() {
        root.items = Object.freeze(root.items.map(function(item) {
            return Object.freeze(Object.assign({}, item, {"unread": false}));
        }));
    }
    function groups() {
        const grouped = {};
        root.items.forEach(function(item) {
            const key = item.application || "Unknown application";
            if (!grouped[key]) grouped[key] = [];
            grouped[key].push(item);
        });
        return Object.keys(grouped).sort().map(function(name) {
            return Object.freeze({"application": name, "items": Object.freeze(grouped[name])});
        });
    }
}
