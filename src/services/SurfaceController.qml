import QtQuick 6.0

QtObject {
    id: root

    property var registry: ({})
    property string openSurfaceId: ""
    property string openScreenKey: ""

    signal surfaceOpened(string id, string screenKey)
    signal surfaceClosed(string id, string screenKey)

    function normalizedScreenKey(screenKey) {
        if (typeof screenKey !== "string" || screenKey.trim().length === 0)
            return "default";
        return screenKey.trim();
    }

    function registerSurface(id, edge) {
        if (typeof id !== "string" || id.length === 0 || typeof edge !== "string"
                || edge.length === 0)
            return false;

        const nextRegistry = Object.assign({}, root.registry);
        nextRegistry[id] = Object.freeze({"id": id, "edge": edge});
        root.registry = Object.freeze(nextRegistry);
        return true;
    }

    function open(id, screenKey) {
        if (!Object.prototype.hasOwnProperty.call(root.registry, id))
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
}
