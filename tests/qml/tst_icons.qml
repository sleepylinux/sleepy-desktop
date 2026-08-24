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

    Component {
        id: registryFactory

        Services.IconRegistry {
            artworkRoot: "file:///package/share/sleepy-artwork"
            manifestSource: "file:///package/share/sleepy-artwork/branding/manifest.json"
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

    function test_registry_resolves_complete_reviewed_manifest() {
        const registry = createTemporaryObject(registryFactory, testCase);
        const logicalNames = [
            "icons.control-center", "icons.network", "icons.bluetooth",
            "icons.volume", "icons.microphone", "icons.brightness",
            "icons.night-light", "icons.focus", "icons.battery",
            "icons.power-profile", "icons.media-play", "icons.media-pause",
            "icons.media-next", "icons.media-previous", "icons.lock",
            "icons.logout", "icons.power", "icons.preset", "icons.keybinding"
        ];

        compare(registry.assetCount, 20);
        verify(registry.sourceFor("branding.primaryMark").endsWith("/branding/logo.svg"));
        for (const name of logicalNames)
            verify(registry.sourceFor(name).startsWith(registry.artworkRoot + "/"), name);
        compare(registry.sourceFor("icons.unknown"), "");
        compare(registry.sourceFor("../icons/power"), "");
        compare(registry.sourceFor(""), "");
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
