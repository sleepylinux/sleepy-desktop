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
        }
    }

    Component {
        id: workspaceFactory

        Services.WorkspaceModel {}
    }

    function test_drawer_is_aligned_to_the_inset_rail() {
        const geometry = createTemporaryObject(geometryFactory, testCase);

        compare(geometry.railX, 12);
        compare(geometry.railY, 12);
        compare(geometry.drawerX, 96);
        compare(geometry.drawerY, geometry.railY);
        compare(geometry.drawerHeight, geometry.railHeight);
        compare(geometry.drawerRight, 456);
    }

    function test_geometry_remains_aligned_when_the_viewport_changes() {
        const geometry = createTemporaryObject(geometryFactory, testCase);
        geometry.viewportHeight = 1224;

        compare(geometry.railHeight, 1200);
        compare(geometry.drawerHeight, 1200);
        compare(geometry.drawerY, 12);
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
