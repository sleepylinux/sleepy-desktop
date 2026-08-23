import QtQuick 6.0
import QtTest 1.0
import "../../src/drawers" as Drawers
import "../../src/panels" as Panels
import "../../src/services" as Services
import "../../src/theme" as Theme

TestCase {
    id: testCase

    name: "WindowPolicy"
    when: windowShown
    visible: true
    width: 1000
    height: 800

    Component {
        id: policyFixtureFactory

        QtObject {
            readonly property Services.SurfaceController controller: Services.SurfaceController {
                Component.onCompleted: registerSurface("quickSettings", "left")
            }
            readonly property Services.SurfaceWindowPolicy first: Services.SurfaceWindowPolicy {
                surfaceController: controller
                surfaceId: "quickSettings"
                screenKey: "DP-1"
            }
            readonly property Services.SurfaceWindowPolicy second: Services.SurfaceWindowPolicy {
                surfaceController: controller
                surfaceId: "quickSettings"
                screenKey: "HDMI-A-1"
            }
        }
    }

    Component {
        id: focusFixtureFactory

        Item {
            id: fixture
            width: 1000
            height: 760

            readonly property Services.SurfaceController controller: Services.SurfaceController {
                Component.onCompleted: registerSurface("quickSettings", "left")
            }
            readonly property Theme.ThemeTokens tokens: Theme.ThemeTokens {}
            readonly property Theme.Palette colors: Theme.Palette {}
            readonly property Services.ArtworkRegistry artwork: Services.ArtworkRegistry {
                primaryMarkSource: ""
            }
            readonly property Services.QuickSettingsState quickSettings: Services.QuickSettingsState {}

            readonly property alias firstRail: firstRail
            readonly property alias secondRail: secondRail
            readonly property alias drawer: drawer

            Panels.RailView {
                id: firstRail
                x: 0
                width: 72
                height: 720
                screenKey: "DP-1"
                tokens: fixture.tokens
                colors: fixture.colors
                artworkRegistry: fixture.artwork
                surfaceController: fixture.controller
                workspaceModel: []
            }

            Panels.RailView {
                id: secondRail
                x: 96
                width: 72
                height: 720
                screenKey: "HDMI-A-1"
                tokens: fixture.tokens
                colors: fixture.colors
                artworkRegistry: fixture.artwork
                surfaceController: fixture.controller
                workspaceModel: []
            }

            Drawers.QuickSettingsView {
                id: drawer
                x: 192
                width: 360
                height: 720
                screenKey: "DP-1"
                surfaceController: fixture.controller
                quickSettingsState: fixture.quickSettings
                tokens: fixture.tokens
                colors: fixture.colors
            }
        }
    }

    function test_only_the_target_screen_drawer_is_visible_and_focusable() {
        const fixture = createTemporaryObject(policyFixtureFactory, testCase);

        compare(fixture.first.railFocusable, true);
        compare(fixture.second.railFocusable, true);
        compare(fixture.first.drawerVisible, false);
        compare(fixture.first.drawerFocusable, false);
        compare(fixture.second.drawerVisible, false);
        compare(fixture.second.drawerFocusable, false);

        fixture.controller.open("quickSettings", "HDMI-A-1");

        compare(Number(fixture.first.drawerVisible)
                + Number(fixture.second.drawerVisible), 1);
        compare(fixture.first.drawerVisible, false);
        compare(fixture.first.drawerFocusable, false);
        compare(fixture.second.drawerVisible, true);
        compare(fixture.second.drawerFocusable, true);
        compare(fixture.controller.openScreenKey, "HDMI-A-1");

        fixture.controller.close("quickSettings", "HDMI-A-1");
        compare(fixture.second.drawerVisible, false);
        compare(fixture.second.drawerFocusable, false);
    }

    function test_escape_returns_focus_to_the_invoking_screen_button() {
        const fixture = createTemporaryObject(focusFixtureFactory, testCase);
        const firstButton = findChild(fixture.firstRail, "quickSettingsButton");
        const secondButton = findChild(fixture.secondRail, "quickSettingsButton");
        verify(firstButton !== null);
        verify(secondButton !== null);

        firstButton.forceActiveFocus();
        keyClick(Qt.Key_Return);
        compare(fixture.controller.openScreenKey, "DP-1");
        compare(fixture.drawer.screenKey, "DP-1");
        compare(fixture.controller.isOpen("quickSettings",
                                          fixture.drawer.screenKey), true);
        compare(fixture.drawer.windowPolicy.drawerVisible, true);
        compare(fixture.visible, true);
        tryCompare(fixture.drawer, "visible", true);

        fixture.drawer.forceActiveFocus();
        verify(fixture.drawer.activeFocus);
        keyClick(Qt.Key_Escape);

        compare(fixture.controller.openSurfaceId, "");
        compare(fixture.controller.openScreenKey, "");
        tryVerify(function() { return firstButton.activeFocus; });
        compare(secondButton.activeFocus, false);
    }
}
