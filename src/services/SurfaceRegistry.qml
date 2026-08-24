import QtQuick 6.0

QtObject {
    id: root

    property var descriptors: Object.freeze({})
    property var descriptorList: Object.freeze([])
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
}
