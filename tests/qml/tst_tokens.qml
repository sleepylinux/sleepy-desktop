import QtQuick 6.0
import QtTest 1.0
import "../../src/theme" as Theme

TestCase {
    id: testCase

    name: "ThemeTokens"

    Component {
        id: tokensFactory

        Theme.ThemeTokens {}
    }

    Component {
        id: paletteFactory

        Theme.Palette {}
    }

    function test_spacing_and_radius_invariants() {
        const tokens = createTemporaryObject(tokensFactory, testCase);

        compare(tokens.gridUnit, 12);
        compare(tokens.shellRadius, 22);
        compare(tokens.innerRadius, 16);
        compare(tokens.railWidth % tokens.gridUnit, 0);
        compare(tokens.drawerWidth % tokens.gridUnit, 0);
    }

    function test_reduced_motion_removes_transition_duration() {
        const tokens = createTemporaryObject(tokensFactory, testCase);

        compare(tokens.motionDuration, 180);
        tokens.reducedMotion = true;
        compare(tokens.motionDuration, 0);
    }

    function test_dark_and_light_palettes_are_opaque_and_distinct() {
        const palette = createTemporaryObject(paletteFactory, testCase);
        const darkBackground = palette.shellBackground;
        const darkSurface = palette.surface;

        compare(darkBackground.a, 1);
        compare(darkSurface.a, 1);
        palette.appearanceMode = "light";
        compare(palette.shellBackground.a, 1);
        compare(palette.surface.a, 1);
        verify(palette.shellBackground !== darkBackground);
        verify(palette.surface !== darkSurface);
    }
}
