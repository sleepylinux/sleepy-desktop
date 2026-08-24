import QtQuick 6.0

QtObject {
    id: root

    property var registry: ({})
    property var surfaceRegistry: null
    property string openSurfaceId: ""
    property string openScreenKey: ""

    signal surfaceOpened(string id, string screenKey)
    signal surfaceClosed(string id, string screenKey)
    signal sessionConfirmationRequested(string action, string screenKey)
    signal powerMenuRequested(string screenKey)
    signal focusReturnRequested(string id, string screenKey)

    function normalizedScreenKey(screenKey) {
        if (typeof screenKey !== "string" || screenKey.trim().length === 0)
            return "default";
        return screenKey.trim();
    }

    function registerDescriptor(descriptor) {
        if (root.surfaceRegistry
                && typeof root.surfaceRegistry.registerDescriptor === "function")
            return root.surfaceRegistry.registerDescriptor(descriptor);

        if (!descriptor || typeof descriptor.id !== "string"
                || descriptor.id.trim().length === 0
                || (descriptor.edge !== "left" && descriptor.edge !== "right"))
            return false;
        const id = descriptor.id.trim();
        if (Object.prototype.hasOwnProperty.call(root.registry, id))
            return false;

        const nextRegistry = Object.assign({}, root.registry);
        nextRegistry[id] = Object.freeze(Object.assign({}, descriptor, {"id": id}));
        root.registry = Object.freeze(nextRegistry);
        return true;
    }

    function registerSurface(id, edge) {
        if (typeof id !== "string" || id.length === 0 || typeof edge !== "string"
                || edge.length === 0)
            return false;
        return root.registerDescriptor({
            "id": id,
            "edge": edge,
            "width": 360,
            "triggerIcon": "icons.control-center",
            "triggerLabel": id,
            "availability": true,
            "initialFocusKey": "close"
        });
    }

    function descriptorFor(id) {
        if (root.surfaceRegistry
                && typeof root.surfaceRegistry.descriptorFor === "function")
            return root.surfaceRegistry.descriptorFor(id);
        if (!Object.prototype.hasOwnProperty.call(root.registry, id))
            return null;
        return root.registry[id];
    }

    function open(id, screenKey) {
        const descriptor = root.descriptorFor(id);
        if (!descriptor || descriptor.availability === false)
            return false;
        const targetScreenKey = root.normalizedScreenKey(screenKey);
        if (root.openSurfaceId === id && root.openScreenKey === targetScreenKey)
            return true;

        const previousId = root.openSurfaceId;
        const previousScreenKey = root.openScreenKey;
        root.openSurfaceId = id;
        root.openScreenKey = targetScreenKey;
        if (previousId.length > 0)
            root.surfaceClosed(previousId, previousScreenKey);
        root.surfaceOpened(id, targetScreenKey);
        return true;
    }

    function close(id, screenKey) {
        if (root.openSurfaceId.length === 0)
            return false;
        if (typeof id === "string" && id.length > 0 && root.openSurfaceId !== id)
            return false;
        if (screenKey !== undefined
                && root.openScreenKey !== root.normalizedScreenKey(screenKey))
            return false;

        const previousId = root.openSurfaceId;
        const previousScreenKey = root.openScreenKey;
        root.openSurfaceId = "";
        root.openScreenKey = "";
        root.surfaceClosed(previousId, previousScreenKey);
        root.focusReturnRequested(previousId, previousScreenKey);
        return true;
    }

    function toggle(id, screenKey) {
        const targetScreenKey = root.normalizedScreenKey(screenKey);
        if (root.openSurfaceId === id && root.openScreenKey === targetScreenKey)
            return root.close(id, targetScreenKey);
        return root.open(id, targetScreenKey);
    }

    function isOpen(id, screenKey) {
        if (root.openSurfaceId !== id)
            return false;
        if (screenKey === undefined)
            return true;
        return root.openScreenKey === root.normalizedScreenKey(screenKey);
    }

    function requestSessionConfirmation(action, screenKey) {
        if (["logout", "reboot", "powerOff"].indexOf(action) < 0)
            return false;
        const target = root.normalizedScreenKey(screenKey);
        if (!root.open("controlCenter", target))
            return false;
        root.sessionConfirmationRequested(action, target);
        return true;
    }


    function requestPowerMenu(screenKey) {
        const target = root.normalizedScreenKey(screenKey);
        if (!root.open("controlCenter", target))
            return false;
        root.powerMenuRequested(target);
        return true;
    }
}
