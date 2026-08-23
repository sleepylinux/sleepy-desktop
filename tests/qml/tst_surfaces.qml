import QtQuick 6.0
import QtTest 1.0
import "../../src/drawers" as Drawers
import "../../src/services" as Services
import "../../src/theme" as Theme

TestCase {
    id: testCase

    name: "ShellSurfaces"
    when: windowShown

    Component {
        id: controllerFactory

        Services.SurfaceController {}
    }

    Component {
        id: stateFactory

        Services.QuickSettingsState {}
    }

    Component {
        id: tokensFactory

        Theme.ThemeTokens {}
    }

    Component {
        id: paletteFactory

        Theme.Palette {}
    }

    Component {
        id: drawerFactory

        Drawers.QuickSettingsView {
            width: 360
            height: 720
        }
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

    function test_unsupported_system_mutations_are_disabled() {
        const state = createTemporaryObject(stateFactory, testCase);
        state.capabilities = {"network.toggle": false};
        const initial = state.networkEnabled;

        compare(state.toggleFeature("network"), false);
        compare(state.networkEnabled, initial);

        state.capabilities = {"network.toggle": true};
        compare(state.toggleFeature("network"), true);
        compare(state.networkEnabled, !initial);
    }

    function test_escape_closes_the_drawer() {
        const controller = createTemporaryObject(controllerFactory, testCase);
        const state = createTemporaryObject(stateFactory, testCase);
        const tokens = createTemporaryObject(tokensFactory, testCase);
        const palette = createTemporaryObject(paletteFactory, testCase);
        controller.registerSurface("quickSettings", "left");
        controller.open("quickSettings");

        const drawer = createTemporaryObject(drawerFactory, testCase, {
            "surfaceController": controller,
            "quickSettingsState": state,
            "tokens": tokens,
            "palette": palette
        });
        drawer.forceActiveFocus();
        verify(drawer.activeFocus);
        keyClick(Qt.Key_Escape);

        compare(controller.openSurfaceId, "");
    }
}
