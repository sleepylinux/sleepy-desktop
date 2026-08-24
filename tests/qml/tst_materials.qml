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
