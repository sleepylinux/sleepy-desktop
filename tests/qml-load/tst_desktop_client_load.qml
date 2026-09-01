import QtQuick 6.0
import QtTest 1.0

TestCase {
    name: "ServiceClientLoad"

    function test_00_desktop_client_loads_without_default_property_errors() {
        const component = Qt.createComponent("../../src/services/DesktopClient.qml");

        compare(component.status, Component.Ready, component.errorString());
    }

    function test_01_command_client_loads_without_default_property_errors() {
        const component = Qt.createComponent("../../src/services/CommandClient.qml");

        compare(component.status, Component.Ready, component.errorString());
    }
}
