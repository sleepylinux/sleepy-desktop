// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0

QtObject {
    id: root
    property var items: Object.freeze([])
    property var archive: Object.freeze([])
    property var serverGroups: Object.freeze([])
    property var popupIds: Object.freeze([])
    property bool dnd: false
    readonly property int unreadCount: items.filter(function(item) { return item.unread; }).length

    function plain(value) { return typeof value === "string" ? value : ""; }
    function normalizedDocument(document) {
        if (!document || typeof document !== "object" || Array.isArray(document)) return null;
        const keys = Object.keys(document);
        if (keys.some(function(key) { return ["schemaVersion","id","applicationId","summary","body","urgency","createdAt","timeoutMs","read","archived","actions"].indexOf(key) < 0; })
                || !["schemaVersion","id","applicationId","summary","body","urgency","createdAt","read","archived","actions"].every(function(key) { return keys.indexOf(key) >= 0; })
                || !Number.isSafeInteger(document.id) || document.id <= 0
                || document.schemaVersion !== 2 || typeof document.applicationId !== "string" || !document.applicationId.length
                || typeof document.summary !== "string" || !document.summary.length
                || typeof document.body !== "string" || typeof document.createdAt !== "string" || !document.createdAt.length
                || ["low","normal","critical"].indexOf(document.urgency) < 0
                || typeof document.read !== "boolean" || typeof document.archived !== "boolean"
                || !Array.isArray(document.actions)
                || (Object.prototype.hasOwnProperty.call(document,"timeoutMs")
                    && document.timeoutMs !== null && (!Number.isSafeInteger(document.timeoutMs) || document.timeoutMs < 0))) return null;
        const actions = [];
        for (const action of document.actions) {
            if (!action || Object.keys(action).sort().join(",") !== "id,label,state"
                    || !root.plain(action.id).length || !root.plain(action.label).length
                    || ["available","expired"].indexOf(action.state) < 0) return null;
            actions.push(Object.freeze({"id":action.id,"label":action.label,"state":action.state}));
        }
        return Object.freeze({"id":document.id,"application":document.applicationId,
            "summary":document.summary,"body":document.body,"urgency":document.urgency,
            "unread":!document.read,"archived":document.archived,
            "createdAt":document.createdAt,"actions":Object.freeze(actions)});
    }
    function acceptDocument(document) {
        const normalized = root.normalizedDocument(document); if (!normalized || normalized.archived) return false;
        const next = root.items.filter(function(item) { return item.id !== normalized.id; });
        next.unshift(normalized);
        root.items = Object.freeze(next.slice(0, 500));
        return true;
    }
    function acceptSnapshot(snapshot) {
        if (!snapshot || Object.keys(snapshot).sort().join(",") !== "active,archive,dnd,groups,popupIds,unreadCount"
                || !Array.isArray(snapshot.active) || !Array.isArray(snapshot.archive)
                || !Array.isArray(snapshot.groups) || !Array.isArray(snapshot.popupIds)
                || !Number.isSafeInteger(snapshot.unreadCount) || snapshot.unreadCount < 0
                || typeof snapshot.dnd !== "boolean"
                || !snapshot.groups.every(function(group) {
                    return group && Object.keys(group).sort().join(",") === "applicationId,notificationIds"
                        && typeof group.applicationId === "string" && group.applicationId.length
                        && Array.isArray(group.notificationIds)
                        && group.notificationIds.every(function(id) { return Number.isSafeInteger(id) && id > 0; });
                }) || !snapshot.popupIds.every(function(id) { return Number.isSafeInteger(id) && id > 0; })) return false;
        const active = [], archived = [];
        for (const item of snapshot.active) { const parsed = root.normalizedDocument(item); if (!parsed || parsed.archived) return false; active.push(parsed); }
        for (const item of snapshot.archive) { const parsed = root.normalizedDocument(item); if (!parsed || !parsed.archived) return false; archived.push(parsed); }
        const calculatedUnread = active.filter(function(item) { return item.unread; }).length;
        if (calculatedUnread !== snapshot.unreadCount) return false;
        root.items = Object.freeze(active); root.archive = Object.freeze(archived);
        root.serverGroups = Object.freeze(snapshot.groups.slice());
        root.popupIds = Object.freeze(snapshot.popupIds.slice()); root.dnd = snapshot.dnd;
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
        return ["added", "updated", "actionExpired"].indexOf(event.change) >= 0;
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
