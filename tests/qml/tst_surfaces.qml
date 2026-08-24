pragma ComponentBehavior: Bound

import QtQuick 6.0
import QtTest 1.0
import "../../src/drawers" as Drawers
import "../../src/services" as Services
import "../../src/theme" as Theme
import "../../src/widgets" as Widgets

TestCase {
    id: testCase

    name: "ShellSurfaces"
    when: windowShown
    visible: true
    width: 640
    height: 800

    readonly property url tintFixture: Qt.resolvedUrl("../fixtures/current-color.svg")

    Component {
        id: controllerFactory

        Services.SurfaceController {}
    }

    Component {
        id: drawerFactory

        Drawers.ControlCenterView {
            width: 360
            height: 720
            surfaceController: Services.SurfaceController {
                Component.onCompleted: registerSurface("quickSettings", "left")
            }
            screenKey: "default"
            systemAdapter: Services.SystemAdapterCore {}
            presetAdapter: Services.PresetAdapterCore {}
            clockService: QtObject { property date currentTime: new Date(2026, 7, 24, 8, 3) }
            tokens: Theme.ThemeTokens {}
            colors: Theme.Palette {}
            effects: Theme.EffectsPolicy { effectsProfile: "none" }
            iconRegistry: QtObject {
                function sourceFor(name) { return testCase.tintFixture; }
            }
            onCloseRequested: surfaceController.close("quickSettings", screenKey)
        }
    }

    Component {
        id: sliderFactory

        Widgets.SliderRow {
            width: 300
            label: "Volume"
            iconName: "icons.volume"
            iconRegistry: QtObject {
                function sourceFor(name) { return testCase.tintFixture; }
            }
            value: 0.2
            capabilityEnabled: false
            tokens: Theme.ThemeTokens {}
            colors: Theme.Palette {}
        }
    }

    SignalSpy {
        id: sliderSpy
        signalName: "valueRequested"
    }

    function test_registry_keeps_exactly_one_extensible_surface_open() {
        const controller = createTemporaryObject(controllerFactory, testCase);
        compare(controller.registerSurface("quickSettings", "left"), true);
        compare(controller.registerSurface("notifications", "right"), true);

        compare(controller.open("quickSettings"), true);
        compare(controller.isOpen("quickSettings"), true);
        compare(controller.open("notifications"), true);
        compare(controller.isOpen("quickSettings"), false);
        compare(controller.isOpen("notifications"), true);
        compare(controller.openSurfaceId, "notifications");

        controller.close();
        compare(controller.openSurfaceId, "");
    }

    function test_unknown_surfaces_do_not_replace_the_open_surface() {
        const controller = createTemporaryObject(controllerFactory, testCase);
        controller.registerSurface("quickSettings", "left");
        controller.open("quickSettings");

        compare(controller.open("missing"), false);
        compare(controller.openSurfaceId, "quickSettings");
    }

    function test_pointer_adjustment_is_capability_gated() {
        const slider = createTemporaryObject(sliderFactory, testCase);
        const pointerArea = findChild(slider, "sliderPointerArea");
        verify(pointerArea !== null);
        sliderSpy.target = slider;
        sliderSpy.clear();

        mouseClick(pointerArea, pointerArea.width * 0.75,
                   pointerArea.height / 2, Qt.LeftButton);
        compare(sliderSpy.count, 0);

        slider.capabilityEnabled = true;
        mouseClick(pointerArea, pointerArea.width * 0.75,
                   pointerArea.height / 2, Qt.LeftButton);
        compare(sliderSpy.count, 1);
        verify(Math.abs(sliderSpy.signalArguments[0][0] - 0.75) < 0.02);
    }

    function test_escape_closes_the_drawer() {
        const drawer = createTemporaryObject(drawerFactory, testCase);
        drawer.surfaceController.open("quickSettings");
        drawer.forceActiveFocus();
        verify(drawer.activeFocus);
        keyClick(Qt.Key_Escape);

        compare(drawer.surfaceController.openSurfaceId, "");
    }
}
