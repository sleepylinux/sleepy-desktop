// SPDX-License-Identifier: GPL-3.0-only
// Modified for Sleepy on 2026-08-31: notification records are daemon-projected.

pragma ComponentBehavior: Bound

import QtQuick
import Sleepy.Config
import qs.services

QtObject {
    id: notif

    property bool popup
    property bool closed
    property var locks: new Set()
    property date time: new Date()
    property string timeStr: qsTr("now")
    property string notificationId
    readonly property string id: notificationId
    property string summary
    property string body
    property string appIcon
    property string appName
    property string image
    property var hints
    property real expireTimeout: GlobalConfig.notifs.defaultExpireTimeout
    property int urgency: 1
    property bool resident
    property bool hasActionIcons
    property list<var> actions

    readonly property bool hasFullscreen: Notifs.hasFullscreen()

    readonly property Timer timeStrTimer: Timer {
        running: !notif.closed
        repeat: true
        interval: 5000
        onTriggered: notif.updateTimeStr()
    }

    readonly property Timer timer: Timer {
        running: notif.popup
        interval: notif.expireTimeout > 0 ? notif.expireTimeout
            : notif.hasFullscreen ? GlobalConfig.notifs.fullscreenExpireTimeout
            : GlobalConfig.notifs.defaultExpireTimeout
        onTriggered: {
            if (GlobalConfig.notifs.expire || notif.hasFullscreen)
                notif.popup = false;
        }
    }

    function updateTimeStr(): void {
        const diff = Date.now() - notif.time.getTime();
        const m = Math.floor(diff / 60000);

        if (m < 1) {
            notif.timeStr = qsTr("now");
            timeStrTimer.interval = 5000;
        } else {
            const h = Math.floor(m / 60);
            const d = Math.floor(h / 24);

            if (d > 0) {
                notif.timeStr = `${d}d`;
                timeStrTimer.interval = 3600000;
            } else if (h > 0) {
                notif.timeStr = `${h}h`;
                timeStrTimer.interval = 300000;
            } else {
                notif.timeStr = `${m}m`;
                timeStrTimer.interval = m < 10 ? 30000 : 60000;
            }
        }
    }

    function lock(item: Item): void {
        locks.add(item);
    }

    function unlock(item: Item): void {
        locks.delete(item);
        if (closed)
            close();
    }

    function close(): void {
        closed = true;
        if (locks.size === 0)
            Notifs.dismiss(notificationId);
    }
}
