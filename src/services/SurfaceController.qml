import QtQuick 6.0

QtObject {
    id: root

    property var registry: ({})
    property string openSurfaceId: ""

    signal surfaceOpened(string id)
    signal surfaceClosed(string id)

    function registerSurface(id, edge) {
        if (typeof id !== "string" || id.length === 0 || typeof edge !== "string"
                || edge.length === 0)
            return false;

        const nextRegistry = Object.assign({}, root.registry);
        nextRegistry[id] = Object.freeze({"id": id, "edge": edge});
        root.registry = Object.freeze(nextRegistry);
        return true;
    }

    function open(id) {
        if (!Object.prototype.hasOwnProperty.call(root.registry, id))
            return false;
        if (root.openSurfaceId === id)
            return true;

        const previous = root.openSurfaceId;
        root.openSurfaceId = id;
        if (previous.length > 0)
            root.surfaceClosed(previous);
        root.surfaceOpened(id);
        return true;
    }

    function close(id) {
        if (root.openSurfaceId.length === 0)
            return false;
        if (typeof id === "string" && id.length > 0 && root.openSurfaceId !== id)
            return false;

        const previous = root.openSurfaceId;
        root.openSurfaceId = "";
        root.surfaceClosed(previous);
        return true;
    }

    function toggle(id) {
        if (root.openSurfaceId === id)
            return root.close(id);
        return root.open(id);
    }

    function isOpen(id) {
        return root.openSurfaceId === id;
    }
}
