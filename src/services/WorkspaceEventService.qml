// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0

QtObject {
    id: root
    required property var events
    required property var daily
    readonly property var items: {
        const capability = events.capability("niri");
        if (!capability.available || !capability.value) return Object.freeze([]);
        const value = capability.value.data !== undefined ? capability.value.data : capability.value;
        return Object.freeze((value.workspaceIds || []).map(function(id) {
            return Object.freeze({"index": id, "name": String(id), "active": false,
                                  "focused": false});
        }));
    }
    readonly property string diagnostic: events.capability("niri").diagnostic
    function focusWorkspace(index) {
        const request = root.daily.overview("focusWorkspace", {"workspaceId": Number(index)});
        return request ? root.daily.sendRequest(request) : false;
    }
}
