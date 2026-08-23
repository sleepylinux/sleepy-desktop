import QtQuick 6.0

QtObject {
    id: root

    property var capabilities: ({})

    property bool networkEnabled: true
    property bool bluetoothEnabled: false
    property bool nightLightEnabled: true
    property bool focusEnabled: false
    property real volume: 0.62
    property real brightness: 0.74

    signal mutationRequested(string capability, var value)

    function capabilityFor(feature) {
        const mapping = {
            "network": "network.toggle",
            "bluetooth": "bluetooth.toggle",
            "nightLight": "nightLight.toggle",
            "focus": "focus.toggle",
            "volume": "audio.volume",
            "brightness": "display.brightness"
        };
        return mapping[feature] || "";
    }

    function supports(feature) {
        const capability = root.capabilityFor(feature);
        return capability.length > 0 && root.capabilities[capability] === true;
    }

    function toggleFeature(feature) {
        if (!root.supports(feature))
            return false;

        const propertyNames = {
            "network": "networkEnabled",
            "bluetooth": "bluetoothEnabled",
            "nightLight": "nightLightEnabled",
            "focus": "focusEnabled"
        };
        const propertyName = propertyNames[feature];
        if (!propertyName)
            return false;

        root[propertyName] = !root[propertyName];
        root.mutationRequested(root.capabilityFor(feature), root[propertyName]);
        return true;
    }

    function setLevel(feature, value) {
        if (!root.supports(feature))
            return false;
        const normalized = Math.max(0, Math.min(1, Number(value)));
        if (feature === "volume")
            root.volume = normalized;
        else if (feature === "brightness")
            root.brightness = normalized;
        else
            return false;
        root.mutationRequested(root.capabilityFor(feature), normalized);
        return true;
    }
}
