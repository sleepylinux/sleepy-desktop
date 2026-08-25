// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0

WorkspaceModel {
    id: root
    property var eventSource: null
    property var dailyClient: null

    function rebuild() {
        if (!root.eventSource) return false;
        const capability = root.eventSource.capability("niri");
        if (!capability.available || !capability.value) {
            root.items = Object.freeze([]);
            root.diagnostic = capability.diagnostic;
            return false;
        }
        const value = capability.value.data !== undefined ? capability.value.data : capability.value;
        root.items = Object.freeze((value.workspaceIds || []).map(function(id) {
            return Object.freeze({"index": id, "name": String(id),
                                  "active": false, "focused": false});
        }));
        root.diagnostic = "";
        root.workspacesChanged();
        return true;
    }
    function refresh() { return root.rebuild(); }
    function focusWorkspace(index) {
        if (!root.dailyClient || !Number.isFinite(Number(index))) return false;
        const request = root.dailyClient.overview("focusWorkspace", {"workspaceId": Number(index)});
        return request ? root.dailyClient.sendRequest(request) : false;
    }
    readonly property Connections eventConnections: Connections {
        target: root.eventSource
        enabled: root.eventSource !== null
        function onEventAccepted(envelope) { root.rebuild(); }
    }
}
