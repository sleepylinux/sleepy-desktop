import QtQuick 6.0
import QtTest 1.0
import "../../src/panels" as Panels
import "../../src/services" as Services

TestCase {
    id: testCase

    name: "ShellGeometry"

    Component {
        id: geometryFactory

        Panels.ShellGeometry {
            viewportHeight: 900
            viewportWidth: 1000
        }
    }

    function test_right_edge_geometry_and_variable_widths() {
        const geometry = createTemporaryObject(geometryFactory, testCase);
        geometry.surfaceEdge = "right";
        geometry.drawerWidth = 408;

        compare(geometry.drawerX, 580);
        compare(geometry.drawerMarginRight, 12);
        compare(geometry.drawerRight, 988);
        compare(geometry.drawerAnchorLeft, false);
        compare(geometry.drawerAnchorRight, true);

        geometry.drawerWidth = 336;
        compare(geometry.drawerX, 652);
        compare(geometry.drawerRight, 988);
    }

    function test_left_edge_variable_width_preserves_rail_gap() {
        const geometry = createTemporaryObject(geometryFactory, testCase);
        geometry.surfaceEdge = "left";
        geometry.drawerWidth = 408;

        compare(geometry.drawerX, 96);
        compare(geometry.drawerRight, 504);
        compare(geometry.drawerAnchorLeft, true);
        compare(geometry.drawerAnchorRight, false);
    }

    Component {
        id: workspaceFactory

        Services.WorkspaceModel {}
    }

    function test_drawer_is_aligned_to_the_inset_rail() {
        const geometry = createTemporaryObject(geometryFactory, testCase);

        compare(geometry.railX, 12);
        compare(geometry.railY, 12);
        compare(geometry.railMarginLeft, 12);
        compare(geometry.railExclusiveZone, 72);
        compare(geometry.railEnvelopeRight, 84);
        compare(geometry.drawerX, 96);
        compare(geometry.drawerMarginLeft, 96);
        compare(geometry.drawerExclusiveZone, 0);
        compare(geometry.drawerY, geometry.railY);
        compare(geometry.drawerHeight, geometry.railHeight);
        compare(geometry.drawerRight, 456);
    }

    function test_geometry_remains_aligned_when_the_viewport_changes_data() {
        return [
            {"tag": "compact", "viewportHeight": 768, "expectedHeight": 744},
            {"tag": "desktop", "viewportHeight": 900, "expectedHeight": 876},
            {"tag": "tall", "viewportHeight": 1440, "expectedHeight": 1416}
        ];
    }

    function test_geometry_remains_aligned_when_the_viewport_changes(data) {
        const geometry = createTemporaryObject(geometryFactory, testCase);
        geometry.viewportHeight = data.viewportHeight;

        compare(geometry.railHeight, data.expectedHeight);
        compare(geometry.drawerHeight, data.expectedHeight);
        compare(geometry.drawerY, 12);
        compare(geometry.railEnvelopeRight + geometry.gap, geometry.drawerX);
    }

    function test_workspace_model_sorts_and_replaces_runtime_state() {
        const workspaces = createTemporaryObject(workspaceFactory, testCase);

        workspaces.acceptWorkspaces(JSON.stringify([
            {"idx": 4, "name": "dev", "is_active": false},
            {"idx": 1, "name": "web", "is_active": true}
        ]));
        compare(workspaces.items.length, 2);
        compare(workspaces.items[0].index, 1);
        compare(workspaces.items[0].active, true);
        compare(workspaces.items[1].index, 4);

        workspaces.acceptWorkspaces(JSON.stringify([
            {"idx": 2, "name": "chat", "is_active": true}
        ]));
        compare(workspaces.items.length, 1);
        compare(workspaces.items[0].name, "chat");
    }

    function test_invalid_workspace_payload_preserves_last_valid_state() {
        const workspaces = createTemporaryObject(workspaceFactory, testCase);
        workspaces.acceptWorkspaces('[{"idx":3,"name":"docs","is_active":true}]');

        compare(workspaces.acceptWorkspaces('{broken'), false);
        compare(workspaces.items.length, 1);
        compare(workspaces.items[0].index, 3);
        verify(workspaces.diagnostic.length > 0);
    }
}
