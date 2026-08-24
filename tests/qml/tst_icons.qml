pragma ComponentBehavior: Bound

import QtQuick 6.0
import QtQuick.Effects 6.5
import QtQuick.Window 6.0
import QtTest 1.0
import "../../src/services" as Services
import "../../src/theme" as Theme
import "../../src/widgets" as Widgets

TestCase {
    id: testCase

    name: "Icons"
    when: windowShown
    visible: true
    width: 360
    height: 240

    readonly property url tintFixture: Qt.resolvedUrl("../fixtures/current-color.svg")
    readonly property url fixtureRoot: Qt.resolvedUrl("../fixtures")
    readonly property url validManifest:
        Qt.resolvedUrl("../fixtures/manifest-valid.json")
    readonly property url traversalManifest:
        Qt.resolvedUrl("../fixtures/manifest-traversal.json")
    readonly property url malformedManifest:
        Qt.resolvedUrl("../fixtures/manifest-malformed.json")

    Component {
        id: registryFactory

        Services.IconRegistry {
            artworkRoot: testCase.fixtureRoot
            manifestSource: testCase.validManifest
        }
    }

    Component {
        id: reactiveResolutionFactory

        QtObject {
            required property var registry
            readonly property url networkSource:
                registry.sourceFor("icons.network")
        }
    }

    Component {
        id: existenceImageFactory

        Image {
            required property string logicalName
            required property var registry
            source: registry.sourceFor(logicalName)
            asynchronous: false
        }
    }

    Component {
        id: iconFactory

        Widgets.SleepyIcon {
            width: 64
            height: 64
            iconSize: 64
            name: "icons.test"
            iconColor: "#34d399"
            accessibleName: "Test icon"
            iconRegistry: QtObject {
                function sourceFor(name) {
                    return name === "icons.test" ? testCase.tintFixture : "";
                }
            }
        }
    }

    Component {
        id: fallbackFactory

        Widgets.SleepyIcon {
            width: 64
            height: 64
            iconSize: 64
            name: "icons.missing"
            iconColor: "#ef4444"
            accessibleName: "Missing icon"
            iconRegistry: QtObject {
                function sourceFor(name) { return ""; }
            }
        }
    }

    Component {
        id: tileFactory

        Widgets.ControlTile {
            label: "Network"
            detail: "Connected"
            iconName: "icons.network"
            active: true
            capabilityEnabled: true
            iconRegistry: QtObject {
                function sourceFor(name) { return testCase.tintFixture; }
            }
            tokens: Theme.ThemeTokens {}
            colors: Theme.Palette {}
        }
    }

    Component {
        id: sliderFactory

        Widgets.SliderRow {
            label: "Volume"
            iconName: "icons.volume"
            value: 0.5
            capabilityEnabled: true
            iconRegistry: QtObject {
                function sourceFor(name) { return testCase.tintFixture; }
            }
            tokens: Theme.ThemeTokens {}
            colors: Theme.Palette {}
        }
    }

    function test_registry_loads_manifest_values_reactively_and_files_exist() {
        const registry = createTemporaryObject(registryFactory, testCase);
        const reactive = createTemporaryObject(reactiveResolutionFactory,
                                               testCase, {"registry": registry});
        verify(registry !== null);
        verify(reactive !== null);
        compare(reactive.networkSource.toString(), "");
        tryCompare(registry, "status", "ready");

        compare(registry.assetCount, 3);
        compare(registry.assets["branding.primaryMark"], "current-color.svg");
        compare(registry.assets["icons.control-center"], "current-color.svg");
        compare(registry.assets["icons.network"], "current-color.svg");
        compare(reactive.networkSource.toString(), testCase.tintFixture.toString());

        for (const logicalName of Object.keys(registry.assets)) {
            const image = createTemporaryObject(existenceImageFactory, testCase, {
                "registry": registry, "logicalName": logicalName
            });
            verify(image !== null);
            tryCompare(image, "status", Image.Ready);
        }
        compare(registry.sourceFor("icons.unknown"), "");
        compare(registry.sourceFor("../icons/power"), "");
        compare(registry.sourceFor(""), "");
    }

    function test_manifest_failures_clear_assets_and_report_error_data() {
        return [
            {"tag": "missing", "source": Qt.resolvedUrl(
                "../fixtures/manifest-missing.json")},
            {"tag": "malformed", "source": malformedManifest},
            {"tag": "traversal", "source": traversalManifest}
        ];
    }

    function test_manifest_failures_clear_assets_and_report_error(data) {
        const registry = createTemporaryObject(registryFactory, testCase, {
            "manifestSource": data.source
        });
        verify(registry !== null);
        tryCompare(registry, "status", "error");
        compare(registry.ready, false);
        verify(registry.errorString.length > 0);
        compare(registry.assetCount, 0);
        compare(registry.sourceFor("icons.power"), "");
    }

    function test_multieffect_mask_colorizes_current_color_svg_pixels() {
        if (GraphicsInfo.api === GraphicsInfo.Software)
            skip("MultiEffect shader is verified in the RHI pass");

        const icon = createTemporaryObject(iconFactory, testCase);
        verify(icon !== null);
        tryCompare(icon, "ready", true);
        waitForRendering(icon);

        const effect = findChild(icon, "iconEffect");
        verify(effect !== null);
        compare(effect.maskEnabled, true);
        fuzzyCompare(effect.colorization, 1.0, 0.001);
        compare(effect.colorizationColor, icon.iconColor);

        wait(80);
        waitForRendering(icon);
        let image = grabImage(icon);
        const greenPixel = "rgba=" + image.red(32, 32) + ","
                         + image.green(32, 32) + "," + image.blue(32, 32)
                         + "," + image.alpha(32, 32);
        verify(image.green(32, 32) > image.red(32, 32) + 60, greenPixel);
        verify(image.green(32, 32) > image.blue(32, 32) + 20);
        verify(image.alpha(32, 32) > 220);

        icon.iconColor = "#ec4899";
        wait(30);
        waitForRendering(icon);
        image = grabImage(icon);
        verify(image.red(32, 32) > image.green(32, 32) + 80);
        verify(image.blue(32, 32) > image.green(32, 32) + 20);
    }

    function test_missing_icon_draws_visible_non_text_fallback() {
        const icon = createTemporaryObject(fallbackFactory, testCase);
        verify(icon !== null);
        compare(icon.available, false);
        compare(icon.fallbackVisible, true);
        waitForRendering(icon);

        const image = grabImage(icon);
        verify(image.alpha(32, 32) > 180);
        verify(image.red(32, 32) > image.green(32, 32) + 80);
    }

    function test_interactive_widgets_use_logical_icons_not_glyph_properties() {
        const tile = createTemporaryObject(tileFactory, testCase);
        const slider = createTemporaryObject(sliderFactory, testCase);

        verify(tile !== null);
        verify(slider !== null);
        compare(tile.iconName, "icons.network");
        compare(slider.iconName, "icons.volume");
        verify(tile.iconText === undefined);
        verify(slider.iconText === undefined);
    }
}
