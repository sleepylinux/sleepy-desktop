import QtQuick 6.0
import QtTest 1.0
import "../../src/theme" as Theme
import "../../src/widgets" as Widgets

TestCase {
    id: testCase

    name: "Materials"
    when: windowShown
    visible: true
    width: 320
    height: 240

    Component {
        id: policyFactory

        Theme.EffectsPolicy {}
    }

    Component {
        id: tokensFactory

        Theme.ThemeTokens {}
    }

    Component {
        id: surfaceFactory

        Item {
            width: 160
            height: 120

            Rectangle {
                anchors.fill: parent
                color: "#ffffff"
            }

            Widgets.GlassSurface {
                id: material
                objectName: "material"
                anchors.fill: parent
                anchors.margins: 12
                colors: Theme.Palette {}
                effects: Theme.EffectsPolicy { effectsProfile: "none" }
            }

            readonly property alias material: material
        }
    }

    Component {
        id: contrastSurfaceFactory

        Item {
            id: fixture
            width: 160
            height: 120
            property color wallpaperColor: "white"
            property string appearanceMode: "dark"
            property string effectsProfile: "full"

            Rectangle { anchors.fill: parent; color: fixture.wallpaperColor }
            Widgets.GlassSurface {
                id: surface
                objectName: "contrastSurface"
                anchors.fill: parent
                radius: 0
                colors: Theme.Palette { appearanceMode: fixture.appearanceMode }
                effects: Theme.EffectsPolicy { effectsProfile: fixture.effectsProfile }
            }
            readonly property alias surface: surface
        }
    }

    function compositeColor(foreground, background, opacity) {
        return Qt.rgba(
            foreground.r * opacity + background.r * (1 - opacity),
            foreground.g * opacity + background.g * (1 - opacity),
            foreground.b * opacity + background.b * (1 - opacity),
            1.0);
    }

    function linearChannel(channel) {
        return channel <= 0.04045 ? channel / 12.92
                                  : Math.pow((channel + 0.055) / 1.055, 2.4);
    }

    function relativeLuminance(color) {
        return 0.2126 * linearChannel(color.r)
             + 0.7152 * linearChannel(color.g)
             + 0.0722 * linearChannel(color.b);
    }

    function contrastRatio(first, second) {
        const firstLuminance = relativeLuminance(first);
        const secondLuminance = relativeLuminance(second);
        return (Math.max(firstLuminance, secondLuminance) + 0.05)
             / (Math.min(firstLuminance, secondLuminance) + 0.05);
    }

    function finalSurfaceColor(colors, effects, wallpaper, sheenColor, raised) {
        let result = compositeColor(raised ? colors.surfaceRaised : colors.surface,
                                    wallpaper, raised
                                    ? effects.raisedSurfaceOpacity
                                    : effects.surfaceOpacity);
        result = compositeColor(colors.contrastLayer, result,
                                effects.contrastLayerOpacity);
        if (sheenColor !== null)
            result = compositeColor(sheenColor, result, effects.sheenOpacity);
        return result;
    }

    function test_profile_policy_data() {
        return [
            {
                "tag": "full",
                "profile": "full",
                "surfaceOpacity": 0.82,
                "raisedOpacity": 0.88,
                "shadow": true,
                "glow": true,
                "motionDuration": 180
            },
            {
                "tag": "reduced",
                "profile": "reduced",
                "surfaceOpacity": 0.94,
                "raisedOpacity": 0.97,
                "shadow": true,
                "glow": false,
                "motionDuration": 90
            },
            {
                "tag": "none",
                "profile": "none",
                "surfaceOpacity": 1.0,
                "raisedOpacity": 1.0,
                "shadow": false,
                "glow": false,
                "motionDuration": 0
            }
        ];
    }

    function test_profile_policy(data) {
        const policy = createTemporaryObject(policyFactory, testCase, {
            "effectsProfile": data.profile
        });

        fuzzyCompare(policy.surfaceOpacity, data.surfaceOpacity, 0.001);
        fuzzyCompare(policy.raisedSurfaceOpacity, data.raisedOpacity, 0.001);
        compare(policy.shadowEnabled, data.shadow);
        compare(policy.glowEnabled, data.glow);
        compare(policy.motionDuration, data.motionDuration);
        compare(policy.decorativeMotionEnabled, data.motionDuration > 0);
        verify(policy.surfaceOpacity >= 0.82,
               "wallpaper-independent contrast floor must remain high");
    }

    function test_reduced_motion_removes_all_decorative_motion() {
        const full = createTemporaryObject(policyFactory, testCase, {
            "effectsProfile": "full",
            "reducedMotion": true
        });
        const reduced = createTemporaryObject(policyFactory, testCase, {
            "effectsProfile": "reduced",
            "reducedMotion": true
        });

        compare(full.motionDuration, 0);
        compare(full.slowMotionDuration, 0);
        compare(full.decorativeMotionEnabled, false);
        compare(reduced.motionDuration, 0);
        compare(reduced.slowMotionDuration, 0);
        compare(reduced.decorativeMotionEnabled, false);
        verify(full.surfaceOpacity >= 0.82);
        verify(reduced.surfaceOpacity >= 0.94);
    }

    function test_theme_tokens_follow_effects_policy_profile_durations() {
        const policy = createTemporaryObject(policyFactory, testCase, {
            "effectsProfile": "reduced"
        });
        const tokens = createTemporaryObject(tokensFactory, testCase, {
            "effectsPolicy": policy
        });

        verify(tokens !== null);
        compare(tokens.motionDuration, 90);
        compare(tokens.slowMotionDuration, 140);

        policy.effectsProfile = "none";
        compare(tokens.motionDuration, 0);
        compare(tokens.slowMotionDuration, 0);

        policy.effectsProfile = "full";
        policy.reducedMotion = true;
        compare(tokens.motionDuration, 0);
        compare(tokens.slowMotionDuration, 0);
    }

    function test_unknown_profile_fails_closed_to_opaque_no_effects() {
        const policy = createTemporaryObject(policyFactory, testCase, {
            "effectsProfile": "surprise"
        });

        compare(policy.profile, "none");
        compare(policy.surfaceOpacity, 1.0);
        compare(policy.shadowEnabled, false);
        compare(policy.glowEnabled, false);
        compare(policy.motionDuration, 0);
    }

    function test_no_effects_surface_renders_opaque() {
        const fixture = createTemporaryObject(surfaceFactory, testCase);
        verify(fixture !== null);
        compare(fixture.material.effectiveSurfaceOpacity, 1.0);
        compare(fixture.material.shadowVisible, false);
        compare(fixture.material.glowVisible, false);

        waitForRendering(fixture);
        const image = grabImage(fixture.material);
        compare(image.alpha(40, 40), 255);
    }

    function test_normal_text_contrast_survives_adversarial_wallpapers_and_sheen_extrema() {
        const wallpapers = [Qt.rgba(0, 0, 0, 1), Qt.rgba(1, 1, 1, 1)];
        const profiles = ["full", "reduced", "none"];
        const appearances = ["dark", "light"];

        for (const appearance of appearances) {
            const colors = createTemporaryObject(Qt.createComponent(
                "../../src/theme/Palette.qml"), testCase,
                {"appearanceMode": appearance});
            verify(colors !== null);

            for (const profile of profiles) {
                const effects = createTemporaryObject(policyFactory, testCase,
                                                       {"effectsProfile": profile});
                const sheenExtrema = effects.highlightEnabled
                    ? [null, colors.highlight, colors.glow] : [null];
                for (const raised of [false, true]) {
                    for (const wallpaper of wallpapers) {
                        for (const sheen of sheenExtrema) {
                            const surface = finalSurfaceColor(
                                colors, effects, wallpaper, sheen, raised);
                            const context = appearance + "/" + profile
                                          + "/raised=" + raised
                                          + "/wall=" + wallpaper
                                          + "/sheen=" + sheen;
                            verify(contrastRatio(colors.textPrimary, surface) >= 4.5,
                                   "textPrimary contrast below 4.5:1: " + context);
                            verify(contrastRatio(colors.textSecondary, surface) >= 4.5,
                                   "textSecondary contrast below 4.5:1: " + context
                                   + " ratio=" + contrastRatio(
                                       colors.textSecondary, surface));
                        }
                    }
                }
            }
        }
    }

    function test_full_material_really_composites_over_wallpaper_pixels() {
        const black = createTemporaryObject(contrastSurfaceFactory, testCase, {
            "wallpaperColor": "black", "appearanceMode": "dark",
            "effectsProfile": "full", "x": 0
        });
        const white = createTemporaryObject(contrastSurfaceFactory, testCase, {
            "wallpaperColor": "white", "appearanceMode": "dark",
            "effectsProfile": "full", "x": 160
        });
        verify(black !== null);
        verify(white !== null);
        verify(black.surface.effectiveSurfaceOpacity < 1.0);
        waitForRendering(black);
        waitForRendering(white);

        const blackImage = grabImage(black);
        const whiteImage = grabImage(white);
        const channelDelta = Math.abs(blackImage.red(80, 55) - whiteImage.red(80, 55))
                           + Math.abs(blackImage.green(80, 55) - whiteImage.green(80, 55))
                           + Math.abs(blackImage.blue(80, 55) - whiteImage.blue(80, 55));
        verify(channelDelta >= 12,
               "full profile must remain visibly translucent, delta=" + channelDelta);

        const colors = createTemporaryObject(Qt.createComponent(
            "../../src/theme/Palette.qml"), testCase, {"appearanceMode": "dark"});
        for (const image of [blackImage, whiteImage]) {
            for (const y of [8, 55, 111]) {
                const renderedSurface = Qt.rgba(image.red(80, y) / 255,
                                                image.green(80, y) / 255,
                                                image.blue(80, y) / 255, 1);
                verify(contrastRatio(colors.textPrimary, renderedSurface) >= 4.5);
                verify(contrastRatio(colors.textSecondary, renderedSurface) >= 4.5);
            }
        }
    }

    function test_full_surface_adds_a_decorative_gradient_sheen() {
        const fixture = createTemporaryObject(surfaceFactory, testCase);
        fixture.material.effects.effectsProfile = "full";

        const sheen = findChild(fixture.material, "materialSheen");
        verify(sheen !== null);
        compare(sheen.visible, true);
        verify(sheen.opacity > 0);

        fixture.material.effects.effectsProfile = "none";
        compare(sheen.visible, false);
    }
}
