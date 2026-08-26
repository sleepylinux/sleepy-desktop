pragma ComponentBehavior: Bound

import QtQuick 6.0
import QtTest 1.0
import "../../src/services" as Services
import "../../src/theme" as Theme
import "../../src/widgets" as Widgets

TestCase {
    id: testCase

    name: "ProductionMotion"
    when: windowShown
    visible: true
    width: 600
    height: 360

    readonly property url tintFixture: Qt.resolvedUrl("../fixtures/current-color.svg")

    Component {
        id: fixtureFactory

        Item {
            id: fixture
            width: 600
            height: 360

            readonly property Theme.EffectsPolicy effects: Theme.EffectsPolicy {}
            readonly property Theme.ThemeTokens tokens: Theme.ThemeTokens {
                effectsPolicy: fixture.effects
            }
            readonly property Theme.Palette colors: Theme.Palette {}
            readonly property Services.SurfaceRegistry registry: Services.SurfaceRegistry {
                Component.onCompleted: registerDescriptor({
                    "id": "controlCenter", "edge": "left", "width": 408,
                    "triggerIcon": "icons.control-center",
                    "triggerLabel": "Control center", "availability": true,
                    "initialFocusKey": "network"
                })
            }
            readonly property Services.SurfaceController controller:
                Services.SurfaceController { surfaceRegistry: fixture.registry }
            readonly property QtObject iconRegistry: QtObject {
                function sourceFor(name) { return testCase.tintFixture; }
            }

            readonly property alias tile: tile
            readonly property alias workspace: workspace

            Widgets.ControlTile {
                id: tile
                label: "Network"
                detail: "Connected"
                iconName: "icons.network"
                iconRegistry: fixture.iconRegistry
                active: false
                capabilityEnabled: true
                tokens: fixture.tokens
                colors: fixture.colors
            }

            Widgets.WorkspaceButton {
                id: workspace
                x: 180
                workspaceIndex: 1
                workspaceName: "one"
                active: false
                tokens: fixture.tokens
                colors: fixture.colors
            }

        }
    }

    function test_components_expose_the_animation_that_uses_profile_duration() {
        const fixture = createTemporaryObject(fixtureFactory, testCase);
        verify(fixture !== null);

        verify(fixture.tile.transitionDuration !== undefined);
        verify(fixture.workspace.transitionDuration !== undefined);

        const cases = [
            {"profile": "full", "duration": 180},
            {"profile": "reduced", "duration": 90},
            {"profile": "none", "duration": 0}
        ];
        for (const current of cases) {
            fixture.effects.reducedMotion = false;
            fixture.effects.effectsProfile = current.profile;
            compare(fixture.tile.transitionDuration, current.duration,
                    current.profile);
            compare(fixture.workspace.transitionDuration, current.duration,
                    current.profile);
        }

        fixture.effects.effectsProfile = "full";
        fixture.effects.reducedMotion = true;
        compare(fixture.tile.transitionDuration, 0);
        compare(fixture.workspace.transitionDuration, 0);
    }
}
