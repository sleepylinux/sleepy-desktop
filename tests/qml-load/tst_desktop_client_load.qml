import QtQuick 6.0
import QtTest 1.0

TestCase {
    name: "DesktopClientLoad"

    function test_component_loads_without_default_property_errors() {
        const component = Qt.createComponent("../../src/services/DesktopClient.qml");

        compare(component.status, Component.Ready, component.errorString());
    }
}
