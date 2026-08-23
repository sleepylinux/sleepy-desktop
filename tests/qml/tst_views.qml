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
            surfaceController: Services.SurfaceController {
                Component.onCompleted: registerSurface("quickSettings", "left")
            }
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
        rail.surfaceController.registerSurface("quickSettings", "left");
        const button = findChild(rail, "quickSettingsButton");
        verify(button !== null);
        button.forceActiveFocus();
        verify(button.activeFocus);
        keyClick(Qt.Key_Return);
        compare(rail.surfaceController.openSurfaceId, "quickSettings");
    }
}
