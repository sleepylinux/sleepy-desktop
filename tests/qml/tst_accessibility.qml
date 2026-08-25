pragma ComponentBehavior: Bound

import QtQuick 6.0
import QtTest 1.0
import "../../src/widgets" as Widgets
import "../../src/services" as Services
import "../../src/theme" as Theme

TestCase {
    id: testCase
    name: "ControlCenterAccessibility"
    when: windowShown
    width: 400
    height: 300
    readonly property url iconFixture: Qt.resolvedUrl("../fixtures/current-color.svg")

    Component {
        id: buttonFactory
        Widgets.IconButton {
            label: "Lock session"
            iconName: "icons.lock"
            iconRegistry: QtObject { function sourceFor(name) { return testCase.iconFixture; } }
            tokens: Theme.ThemeTokens {}
            colors: Theme.Palette {}
        }
    }

    Component {
        id: toggleFactory
        Widgets.CompactToggle {
            label: "Network"
            detail: "Connected"
            iconName: "icons.network"
            checked: true
            capabilityEnabled: true
            busy: false
            iconRegistry: QtObject { function sourceFor(name) { return testCase.iconFixture; } }
            tokens: Theme.ThemeTokens {}
            colors: Theme.Palette {}
        }
    }

    function test_interactive_controls_have_names_roles_and_state() {
        const button = createTemporaryObject(buttonFactory, testCase);
        compare(button.Accessible.name, "Lock session");
        compare(button.Accessible.role, Accessible.Button);
        const toggle = createTemporaryObject(toggleFactory, testCase);
        compare(toggle.Accessible.name, "Network");
        compare(toggle.Accessible.role, Accessible.CheckBox);
        compare(toggle.Accessible.checked, true);
    }
}
