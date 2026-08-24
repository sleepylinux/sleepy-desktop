pragma ComponentBehavior: Bound

import QtQuick 6.0
import QtTest 1.0
import "../../src/panels" as Panels
import "../../src/services" as Services
import "../../src/theme" as Theme

TestCase {
    id: testCase

    name: "ShellViews"
    when: windowShown
    width: 800
    height: 800

    readonly property url tintFixture: Qt.resolvedUrl("../fixtures/current-color.svg")

    Component {
        id: artworkFactory

        Services.ArtworkRegistry {
            primaryMarkSource: "file:///package/share/sleepy-artwork/branding/logo.svg"
        }
    }

    Component {
        id: railFactory

        Panels.RailView {
            width: 72
            height: 720
            tokens: Theme.ThemeTokens {}
            colors: Theme.Palette {}
            artworkRegistry: Services.ArtworkRegistry {
                primaryMarkSource: ""
            }
            iconRegistry: QtObject {
                function sourceFor(name) { return testCase.tintFixture; }
            }
            surfaceRegistry: Services.SurfaceRegistry {
                Component.onCompleted: registerDescriptor({
                    "id": "quickSettings", "edge": "left", "width": 360,
                    "triggerIcon": "icons.control-center",
                    "triggerLabel": "Quick settings", "availability": true,
                    "initialFocusKey": "close"
                })
            }
            surfaceController: Services.SurfaceController {
                Component.onCompleted: registerSurface("quickSettings", "left")
            }
            effects: Theme.EffectsPolicy { effectsProfile: "none" }
            workspaceModel: [
                {"index": 1, "name": "web", "active": true},
                {"index": 3, "name": "dev", "active": false}
            ]
        }
    }

    function test_artwork_registry_resolves_only_logical_names() {
        const artwork = createTemporaryObject(artworkFactory, testCase);

        compare(artwork.sourceFor("branding.primaryMark"),
                "file:///package/share/sleepy-artwork/branding/logo.svg");
        compare(artwork.sourceFor("branding.unknown"), "");
    }

    function test_rail_renders_dynamic_workspaces_and_toggles_quick_settings() {
        const rail = createTemporaryObject(railFactory, testCase);

        compare(rail.workspaceCount, 2);
        const button = findChild(rail, "quickSettingsButton");
        verify(button !== null);
        button.forceActiveFocus();
        verify(button.activeFocus);
        keyClick(Qt.Key_Return);
        compare(rail.surfaceController.openSurfaceId, "quickSettings");
    }
}
