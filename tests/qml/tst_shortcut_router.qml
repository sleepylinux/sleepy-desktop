import QtQuick 6.0
import QtTest 1.0
import "../../src/services" as Services

TestCase {
    id: testCase
    name: "ShortcutRouter"

    Component {
        id: factory
        Services.ShortcutRouter {
            surfaceController: Services.SurfaceController {
                Component.onCompleted: registerSurface("controlCenter", "left")
            }
        }
    }

    function fresh() { return createTemporaryObject(factory, testCase); }

    function test_every_invocation_uses_fresh_bounded_niri_query() {
        const router = fresh();
        compare(router.queryTimeoutMs, 900);
        compare(router.beginFocusedOutputQuery().join(" "), "niri msg --json focused-output");
        compare(router.activeQueryGeneration, 1);
        compare(router.beginFocusedOutputQuery().join(" "), "niri msg --json focused-output");
        compare(router.activeQueryGeneration, 2);
        compare(router.acceptFocusedOutputResult(1, 0, '{"name":"DP-1"}', false), false);
        compare(router.acceptFocusedOutputResult(2, 0, '{"name":"DP-2"}', false), "DP-2");
    }

    function test_failed_or_malformed_output_does_not_change_surface() {
        const router = fresh();
        router.surfaceController.open("controlCenter", "DP-1");
        router.beginFocusedOutputQuery();
        compare(router.acceptFocusedOutputResult(1, 4, "", false), false);
        compare(router.surfaceController.openScreenKey, "DP-1");
        router.beginFocusedOutputQuery();
        compare(router.acceptFocusedOutputResult(2, 0, '{}', false), false);
        compare(router.surfaceController.openScreenKey, "DP-1");
    }

    function test_two_screens_keep_one_surface_and_correct_provenance() {
        const router = fresh();
        verify(router.routeOnOutput("surface.controlCenter.toggle", "DP-1"));
        compare(router.surfaceController.openScreenKey, "DP-1");
        verify(router.routeOnOutput("surface.controlCenter.toggle", "HDMI-A-1"));
        compare(router.surfaceController.openScreenKey, "HDMI-A-1");
        compare(router.surfaceController.openSurfaceId, "controlCenter");
    }

    function test_unknown_action_preserves_open_surface() {
        const router = fresh();
        router.surfaceController.open("controlCenter", "DP-1");
        compare(router.routeOnOutput("unknown.action", "DP-2"), false);
        compare(router.surfaceController.openScreenKey, "DP-1");
    }
}
