pragma ComponentBehavior: Bound

import QtQuick 6.0
import "../services" as Services
import "../widgets" as Widgets

FocusScope {
    id: root

    required property var descriptor
    required property var surfaceController
    required property var tokens
    required property var colors
    required property var effects
    property string screenKey: "default"
    property var focusTargets: ({})

    default property alias contentData: contentContainer.data

    readonly property Services.SurfaceWindowPolicy windowPolicy:
        Services.SurfaceWindowPolicy {
            surfaceController: root.surfaceController
            surfaceId: root.descriptor.id
            screenKey: root.screenKey
            descriptor: root.descriptor
        }
    readonly property Item initialFocusItem: {
        const key = root.windowPolicy.initialFocusKey;
        if (!root.focusTargets || !Object.prototype.hasOwnProperty.call(root.focusTargets, key))
            return null;
        const candidate = root.focusTargets[key];
        return candidate && typeof candidate.forceActiveFocus === "function"
            ? candidate : null;
    }

    implicitWidth: descriptor.width
    implicitHeight: 720
    visible: windowPolicy.drawerVisible
    focus: visible

    function focusInitial() {
        if (root.initialFocusItem) {
            root.initialFocusItem.forceActiveFocus();
            return true;
        }
        root.forceActiveFocus();
        return false;
    }

    Keys.onEscapePressed: event => {
        root.surfaceController.close(root.descriptor.id, root.screenKey);
        event.accepted = true;
    }

    Widgets.GlassSurface {
        anchors.fill: parent
        radius: root.tokens.shellRadius
        colors: root.colors
        effects: root.effects
    }

    Item {
        id: contentContainer
        anchors.fill: parent
    }

    Connections {
        target: root.surfaceController

        function onSurfaceOpened(id, screenKey) {
            if (id === root.descriptor.id && screenKey === root.screenKey)
                Qt.callLater(root.focusInitial);
        }
    }
}
