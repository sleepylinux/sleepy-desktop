// SPDX-License-Identifier: GPL-3.0-only

pragma ComponentBehavior: Bound

import QtQuick 6.0
import Quickshell
import "../panels" as Panels

Scope {
    id: root
    required property var tokens
    required property var colors
    required property var effects
    required property var iconRegistry
    required property var surfaceRegistry
    required property var surfaceController
    required property var dailyState

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: window
            required property var modelData
            readonly property string screenKey: String(modelData.name)
            readonly property string surfaceId: root.surfaceController.openSurfaceId
            readonly property var descriptor: root.surfaceRegistry.descriptorFor(surfaceId)
            readonly property bool dailySurface: ["notifications", "launcher", "overview", "widgets", "personalization"].indexOf(surfaceId) >= 0
            readonly property Panels.ShellGeometry geometry: Panels.ShellGeometry {
                viewportHeight: window.modelData.height; viewportWidth: window.modelData.width
                inset: root.tokens.outerInset; railWidth: root.tokens.railWidth
                gap: root.tokens.drawerGap
                drawerWidth: window.descriptor ? window.descriptor.width : root.tokens.drawerWidth
                surfaceEdge: window.descriptor ? window.descriptor.edge : "right"
            }
            screen: modelData
            visible: dailySurface && root.surfaceController.openScreenKey === screenKey
            implicitWidth: geometry.drawerWidth
            color: "transparent"; exclusionMode: ExclusionMode.Ignore
            focusable: visible; aboveWindows: true
            anchors { top: true; bottom: true; left: geometry.drawerAnchorLeft; right: geometry.drawerAnchorRight }
            margins.top: geometry.drawerY; margins.bottom: geometry.drawerY
            margins.left: geometry.drawerAnchorLeft ? geometry.drawerMarginLeft : 0
            margins.right: geometry.drawerAnchorRight ? geometry.drawerMarginRight : 0

            DailySurfaceView {
                id: view
                anchors.fill: parent
                descriptor: window.descriptor || ({"id": "widgets", "edge": "right", "width": 420,
                    "triggerIcon": "icons.calendar", "triggerLabel": "Daily widgets",
                    "availability": true, "initialFocusKey": "calendar"})
                screenKey: window.screenKey
                surfaceController: root.surfaceController
                tokens: root.tokens; colors: root.colors; effects: root.effects
                iconRegistry: root.iconRegistry; dailyState: root.dailyState
                Component.onCompleted: {
                    ["notifications", "launcher", "overview", "widgets", "personalization"]
                        .forEach(function(id) {
                            root.surfaceRegistry.registerInstance(id, screenKey, view);
                        });
                }
            }
        }
    }
}
