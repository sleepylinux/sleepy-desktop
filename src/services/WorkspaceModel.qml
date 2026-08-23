import QtQuick 6.0

QtObject {
    id: root

    property var items: []
    property string diagnostic: ""

    signal workspacesChanged

    function acceptWorkspaces(payload) {
        try {
            const parsed = JSON.parse(payload);
            if (!Array.isArray(parsed))
                throw new Error("workspace response must be an array");

            const normalized = parsed.map(function(workspace) {
                const index = Number(workspace.idx);
                if (!Number.isFinite(index))
                    throw new Error("workspace index must be numeric");
                return Object.freeze({
                    "index": index,
                    "name": typeof workspace.name === "string" ? workspace.name : String(index),
                    "active": workspace.is_active === true,
                    "focused": workspace.is_focused === true
                });
            });
            normalized.sort(function(left, right) { return left.index - right.index; });
            root.items = Object.freeze(normalized);
            root.diagnostic = "";
            root.workspacesChanged();
            return true;
        } catch (error) {
            root.diagnostic = "Ignoring invalid Niri workspace response: " + error.message;
            console.warn("Sleepy desktop: " + root.diagnostic);
            return false;
        }
    }
}
