import QtQuick 6.0

QtObject {
    id: root

    property var descriptors: Object.freeze({})
    property var descriptorList: Object.freeze([])
    property var instances: Object.freeze({})
    readonly property int descriptorCount: descriptorList.length

    function validNonEmptyString(value) {
        return typeof value === "string" && value.trim().length > 0;
    }

    function normalizedDescriptor(candidate) {
        if (!candidate || !validNonEmptyString(candidate.id)
                || (candidate.edge !== "left" && candidate.edge !== "right")
                || typeof candidate.width !== "number"
                || !Number.isFinite(candidate.width) || candidate.width <= 0
                || !validNonEmptyString(candidate.triggerIcon)
                || !validNonEmptyString(candidate.triggerLabel)
                || typeof candidate.availability !== "boolean"
                || !validNonEmptyString(candidate.initialFocusKey))
            return null;

        return Object.freeze({
            "id": candidate.id.trim(),
            "edge": candidate.edge,
            "width": candidate.width,
            "triggerIcon": candidate.triggerIcon.trim(),
            "triggerLabel": candidate.triggerLabel.trim(),
            "availability": candidate.availability,
            "initialFocusKey": candidate.initialFocusKey.trim()
        });
    }

    function registerDescriptor(candidate) {
        const descriptor = normalizedDescriptor(candidate);
        if (!descriptor
                || Object.prototype.hasOwnProperty.call(root.descriptors,
                                                        descriptor.id))
            return false;

        const nextDescriptors = Object.assign({}, root.descriptors);
        nextDescriptors[descriptor.id] = descriptor;
        root.descriptors = Object.freeze(nextDescriptors);
        root.descriptorList = Object.freeze(root.descriptorList.concat([descriptor]));
        return true;
    }

    function descriptorFor(id) {
        if (typeof id !== "string"
                || !Object.prototype.hasOwnProperty.call(root.descriptors, id))
            return null;
        return root.descriptors[id];
    }

    function availableDescriptors(edge) {
        return root.descriptorList.filter(function(descriptor) {
            return descriptor.availability
                && (edge === undefined || edge === "" || descriptor.edge === edge);
        });
    }
    function setAvailability(id, available) {
        const current = root.descriptorFor(id);
        if (!current || typeof available !== "boolean") return false;
        if (current.availability === available) return true;
        const replacement = Object.freeze(Object.assign({}, current, {"availability": available}));
        const next = Object.assign({}, root.descriptors); next[id] = replacement;
        root.descriptors = Object.freeze(next);
        root.descriptorList = Object.freeze(root.descriptorList.map(function(item) {
            return item.id === id ? replacement : item;
        }));
        return true;
    }

    function registerInstance(surfaceId, screenKey, instance) {
        if (!root.descriptorFor(surfaceId) || !root.validNonEmptyString(screenKey)
                || !instance)
            return false;
        const key = surfaceId + "\u0000" + screenKey.trim();
        if (Object.prototype.hasOwnProperty.call(root.instances, key))
            return false;
        const next = Object.assign({}, root.instances);
        next[key] = instance;
        root.instances = Object.freeze(next);
        return true;
    }

    function instanceFor(surfaceId, screenKey) {
        const key = surfaceId + "\u0000" + String(screenKey).trim();
        return Object.prototype.hasOwnProperty.call(root.instances, key)
             ? root.instances[key] : null;
    }

    function registerDailyDesktop() {
        const definitions = [
            ["notifications", "right", 408, "icons.notification", "Notifications", "notifications"],
            ["launcher", "left", 520, "icons.launcher", "Launcher", "search"],
            ["overview", "left", 640, "icons.overview", "Overview", "workspaces"],
            ["widgets", "right", 420, "icons.calendar", "Daily widgets", "calendar"],
            ["personalization", "right", 440, "icons.theme", "Personalization", "themes"]
        ];
        let changed = false;
        definitions.forEach(function(entry) {
            changed = root.registerDescriptor({
                "id": entry[0], "edge": entry[1], "width": entry[2],
                "triggerIcon": entry[3], "triggerLabel": entry[4],
                "availability": false, "initialFocusKey": entry[5]
            }) || changed;
        });
        return changed;
    }
}
