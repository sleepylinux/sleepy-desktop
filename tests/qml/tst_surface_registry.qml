pragma ComponentBehavior: Bound

import QtQuick 6.0
import QtTest 1.0
import "../../src/panels" as Panels
import "../../src/services" as Services
import "../../src/surfaces" as Surfaces
import "../../src/theme" as Theme

TestCase {
    id: testCase

    name: "SurfaceRegistry"
    when: windowShown
    visible: true
    width: 1200
    height: 800

    readonly property url tintFixture: Qt.resolvedUrl("../fixtures/current-color.svg")

    readonly property var controlCenterDescriptor: Object.freeze({
        "id": "controlCenter",
        "edge": "left",
        "width": 408,
        "triggerIcon": "icons.control-center",
        "triggerLabel": "Control center",
        "availability": true,
        "initialFocusKey": "network"
    })

    Component {
        id: registryFactory

        Services.SurfaceRegistry {}
    }

    Component {
        id: controllerFixtureFactory

        QtObject {
            id: fixture
            readonly property Services.SurfaceRegistry registry: Services.SurfaceRegistry {}
            readonly property Services.SurfaceController controller: Services.SurfaceController {
                surfaceRegistry: fixture.registry
            }
        }
    }

    Component {
        id: frameFixtureFactory

        Item {
            id: fixture
            width: 1000
            height: 760

            readonly property Services.SurfaceRegistry registry: Services.SurfaceRegistry {}
            readonly property Services.SurfaceController controller: Services.SurfaceController {
                surfaceRegistry: fixture.registry
            }
            readonly property Theme.ThemeTokens tokens: Theme.ThemeTokens {}
            readonly property Theme.Palette colors: Theme.Palette {}
            readonly property Theme.EffectsPolicy effects: Theme.EffectsPolicy {
                effectsProfile: "none"
            }
            readonly property var descriptor: testCase.controlCenterDescriptor
            readonly property alias firstFrame: firstFrame
            readonly property alias secondFrame: secondFrame
            readonly property alias firstTarget: firstTarget
            readonly property alias secondTarget: secondTarget

            Component.onCompleted: registry.registerDescriptor(descriptor)

            Surfaces.DrawerFrame {
                id: firstFrame
                x: 0
                height: 720
                descriptor: fixture.descriptor
                screenKey: "DP-1"
                surfaceController: fixture.controller
                tokens: fixture.tokens
                colors: fixture.colors
                effects: fixture.effects
                focusTargets: ({"network": firstTarget})

                Item {
                    id: firstTarget
                    objectName: "firstNetworkTarget"
                    width: 40
                    height: 40
                    activeFocusOnTab: true
                }
            }

            Surfaces.DrawerFrame {
                id: secondFrame
                x: 440
                height: 720
                descriptor: fixture.descriptor
                screenKey: "HDMI-A-1"
                surfaceController: fixture.controller
                tokens: fixture.tokens
                colors: fixture.colors
                effects: fixture.effects
                focusTargets: ({"network": secondTarget})

                Item {
                    id: secondTarget
                    objectName: "secondNetworkTarget"
                    width: 40
                    height: 40
                    activeFocusOnTab: true
                }
            }
        }
    }

    Component {
        id: railFixtureFactory

        Panels.RailView {
            width: 72
            height: 720
            tokens: Theme.ThemeTokens {}
            colors: Theme.Palette {}
            artworkRegistry: Services.ArtworkRegistry { primaryMarkSource: "" }
            iconRegistry: QtObject {
                function sourceFor(name) { return testCase.tintFixture; }
            }
            surfaceRegistry: Services.SurfaceRegistry {
                Component.onCompleted: registerDescriptor(testCase.controlCenterDescriptor)
            }
            surfaceController: Services.SurfaceController {
                Component.onCompleted: registerDescriptor(testCase.controlCenterDescriptor)
            }
            workspaceModel: []
            effects: Theme.EffectsPolicy { effectsProfile: "none" }
        }
    }

    function test_descriptor_contract_is_validated_and_immutable() {
        const registry = createTemporaryObject(registryFactory, testCase);
        compare(registry.registerDescriptor(controlCenterDescriptor), true);
        compare(registry.registerDescriptor(controlCenterDescriptor), false);
        compare(registry.descriptorCount, 1);

        const stored = registry.descriptorFor("controlCenter");
        compare(stored.id, "controlCenter");
        compare(stored.edge, "left");
        compare(stored.width, 408);
        compare(stored.triggerIcon, "icons.control-center");
        compare(stored.triggerLabel, "Control center");
        compare(stored.availability, true);
        compare(stored.initialFocusKey, "network");
        try {
            stored.width = 12;
        } catch (error) {
            // Frozen descriptor assignment throws under strict JS engines.
        }
        compare(registry.descriptorFor("controlCenter").width, 408);
    }

    function test_invalid_descriptors_are_rejected_without_mutation_data() {
        return [
            {"tag": "missing-id", "descriptor": {
                "edge": "left", "width": 408, "triggerIcon": "icons.control-center",
                "triggerLabel": "Control center", "availability": true,
                "initialFocusKey": "network"}},
            {"tag": "bad-edge", "descriptor": {
                "id": "bad", "edge": "top", "width": 408,
                "triggerIcon": "icons.control-center", "triggerLabel": "Bad",
                "availability": true, "initialFocusKey": "network"}},
            {"tag": "zero-width", "descriptor": {
                "id": "bad", "edge": "right", "width": 0,
                "triggerIcon": "icons.control-center", "triggerLabel": "Bad",
                "availability": true, "initialFocusKey": "network"}},
            {"tag": "missing-focus-key", "descriptor": {
                "id": "bad", "edge": "right", "width": 408,
                "triggerIcon": "icons.control-center", "triggerLabel": "Bad",
                "availability": true, "initialFocusKey": ""}},
            {"tag": "non-boolean-availability", "descriptor": {
                "id": "bad", "edge": "right", "width": 408,
                "triggerIcon": "icons.control-center", "triggerLabel": "Bad",
                "availability": "sometimes", "initialFocusKey": "network"}}
        ];
    }

    function test_invalid_descriptors_are_rejected_without_mutation(data) {
        const registry = createTemporaryObject(registryFactory, testCase);
        compare(registry.registerDescriptor(data.descriptor), false);
        compare(registry.descriptorCount, 0);
    }

    function test_controller_uses_availability_and_keeps_compatibility_method() {
        const fixture = createTemporaryObject(controllerFixtureFactory, testCase);
        compare(fixture.registry.registerDescriptor(controlCenterDescriptor), true);
        compare(fixture.registry.registerDescriptor({
            "id": "notifications", "edge": "right", "width": 360,
            "triggerIcon": "icons.control-center", "triggerLabel": "Notifications",
            "availability": false, "initialFocusKey": "notifications"
        }), true);

        compare(fixture.controller.open("controlCenter", "DP-1"), true);
        compare(fixture.controller.open("notifications", "DP-1"), false);
        compare(fixture.controller.openSurfaceId, "controlCenter");
        compare(fixture.controller.registerSurface("quickSettings", "left"), true);
        compare(fixture.controller.open("quickSettings", "HDMI-A-1"), true);
        compare(fixture.controller.openSurfaceId, "quickSettings");
        compare(fixture.controller.openScreenKey, "HDMI-A-1");
    }

    function test_focus_key_resolves_to_each_screen_instances_own_item() {
        const fixture = createTemporaryObject(frameFixtureFactory, testCase);
        compare(fixture.descriptor.initialFocusKey, "network");
        verify(fixture.descriptor.initialFocusItem === undefined);

        fixture.controller.open("controlCenter", "DP-1");
        tryVerify(function() { return fixture.firstTarget.activeFocus; });
        compare(fixture.secondTarget.activeFocus, false);
        compare(fixture.firstFrame.initialFocusItem, fixture.firstTarget);
        compare(fixture.secondFrame.initialFocusItem, fixture.secondTarget);

        fixture.controller.open("controlCenter", "HDMI-A-1");
        tryVerify(function() { return fixture.secondTarget.activeFocus; });
        compare(fixture.firstTarget.activeFocus, false);
        compare(fixture.controller.openScreenKey, "HDMI-A-1");
    }

    function test_escape_closes_only_the_target_screen_frame() {
        const fixture = createTemporaryObject(frameFixtureFactory, testCase);
        fixture.controller.open("controlCenter", "DP-1");
        tryVerify(function() { return fixture.firstTarget.activeFocus; });
        keyClick(Qt.Key_Escape);

        compare(fixture.controller.openSurfaceId, "");
        compare(fixture.controller.openScreenKey, "");
        compare(fixture.firstFrame.visible, false);
        compare(fixture.secondFrame.visible, false);
    }

    function test_rail_triggers_are_created_from_available_descriptors() {
        const rail = createTemporaryObject(railFixtureFactory, testCase);
        tryCompare(rail, "triggerCount", 1);
        const button = findChild(rail, "controlCenterButton");
        verify(button !== null);
        compare(button.accessibleName, "Control center");
        button.forceActiveFocus();
        keyClick(Qt.Key_Return);
        compare(rail.surfaceController.openSurfaceId, "controlCenter");
    }
}
