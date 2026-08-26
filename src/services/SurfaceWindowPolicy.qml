import QtQuick 6.0

QtObject {
    id: root

    required property var surfaceController
    required property string surfaceId
    required property string screenKey
    property var descriptor: null

    property bool invokedFromRail: false

    readonly property bool railFocusable: true
    readonly property bool drawerVisible:
        root.surfaceController.isOpen(root.surfaceId, root.screenKey)
    readonly property bool drawerFocusable: root.drawerVisible
    readonly property string initialFocusKey:
        descriptor && typeof descriptor.initialFocusKey === "string"
        ? descriptor.initialFocusKey : ""

    signal focusReturnRequested()

    function toggleFromRail() {
        if (root.drawerVisible)
            return root.surfaceController.close(root.surfaceId, root.screenKey);

        root.invokedFromRail = true;
        const opened = root.surfaceController.open(root.surfaceId, root.screenKey);
        if (!opened)
            root.invokedFromRail = false;
        return opened;
    }

    readonly property Connections controllerConnections: Connections {
        target: root.surfaceController

        function onSurfaceClosed(id, screenKey) {
            if (id !== root.surfaceId || screenKey !== root.screenKey
                    || !root.invokedFromRail)
                return;

            root.invokedFromRail = false;
            root.focusReturnRequested();
        }
    }
}
