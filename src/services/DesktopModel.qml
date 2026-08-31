// SPDX-License-Identifier: GPL-3.0-only
// Modified for Sleepy on 2026-08-31: typed projection of the v3 desktop snapshot.

pragma Singleton

import QtQuick 6.0

QtObject {
    id: root

    readonly property bool available: DesktopClient.connectionState === "ready"
    readonly property string connectionState: DesktopClient.connectionState
    readonly property string diagnostic: DesktopClient.diagnostic
    readonly property var generation: DesktopClient.generation
    readonly property var snapshot: DesktopClient.snapshot || ({})
    readonly property var system: root.snapshot.system || ({})
    readonly property var compositor: root.snapshot.compositor || ({})
    readonly property var notifications: root.snapshot.notifications || ({})
    readonly property var launcher: root.snapshot.launcher || ({})
    readonly property var calendar: root.snapshot.calendar || ({})
    readonly property var weather: root.snapshot.weather || ({})
    readonly property var appearance: root.snapshot.appearance || ({})
    readonly property var resources: root.snapshot.resources || ({})
    readonly property var utilities: root.snapshot.utilities || ({})

    function own(object, key) {
        return object && Object.prototype.hasOwnProperty.call(object, key);
    }

    function capability(section, key) {
        const container = root[section] || {};
        if (root.own(container, key))
            return container[key];
        return Object.freeze({
            "status": "unavailable",
            "diagnostic": Object.freeze({"message": "Capability has not reported"})
        });
    }

    function capabilityData(section, key, fallback) {
        const record = root.capability(section, key);
        return record && record.status === "available" && root.own(record, "data")
            ? record.data : fallback;
    }

    function command(_family, _command, _requestId) {
        return false;
    }
}
