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
        compare(tokens.railBrandTopInset, 15);
        compare(tokens.railWorkspaceTop, 84);
        compare(tokens.railBottomInset, 15);
        compare(tokens.drawerHeaderHeight, 54);
        compare(tokens.drawerCloseSize, 38);
        compare(tokens.sliderRowHeight, 64);
    }

    function test_reduced_motion_removes_transition_duration() {
        const tokens = createTemporaryObject(tokensFactory, testCase);

        compare(tokens.motionDuration, 180);
        tokens.reducedMotion = true;
        compare(tokens.motionDuration, 0);
    }

    function test_dark_and_light_palettes_are_opaque_and_distinct() {
        const palette = createTemporaryObject(paletteFactory, testCase);
        const darkBackground = String(palette.shellBackground);
        const darkSurface = String(palette.surface);

        verify(/^#[0-9a-f]{6}$/i.test(darkBackground));
        verify(/^#[0-9a-f]{6}$/i.test(darkSurface));
        palette.appearanceMode = "light";
        verify(/^#[0-9a-f]{6}$/i.test(String(palette.shellBackground)));
        verify(/^#[0-9a-f]{6}$/i.test(String(palette.surface)));
        verify(String(palette.shellBackground) !== darkBackground);
        verify(String(palette.surface) !== darkSurface);
    }
}
