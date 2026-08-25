// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0
import QtTest 1.0
import "../../src/drawers" as Drawers
import "../../src/panels" as Panels
import "../../src/services" as Services
import "../../src/theme" as Theme

TestCase {
    id: testCase
    name: "M3ProductionSurfaces"
    when: windowShown
    visible: true
    width: 760
    height: 360

    Component {
        id: surfaceFactory
        Item {
            id: fixture
            width: 360; height: 320
            property string screenKey: "DP-1"
            property string appearance: "dark"
            property string effectsProfile: "full"
            readonly property alias view: dailyView
            readonly property Theme.EffectsPolicy effects: Theme.EffectsPolicy {
                effectsProfile: fixture.effectsProfile
            }
            readonly property Theme.Palette colors: Theme.Palette {
                appearanceMode: fixture.appearance
            }
            readonly property Theme.ThemeTokens tokens: Theme.ThemeTokens {
                effectsPolicy: fixture.effects
            }
            readonly property Services.SurfaceRegistry registry: Services.SurfaceRegistry {}
            readonly property Services.SurfaceController controller: Services.SurfaceController {
                surfaceRegistry: fixture.registry
            }
            readonly property QtObject dailyState: QtObject {
                property QtObject daily: QtObject { property string errorString: "" }
                property var notifications: null
                function stateFor(id) { return "ready"; }
                function itemsFor(id) {
                    return [{"id":"resources","name":"CPU, memory and load","summary":"CPU 18% · RAM 42% · load 0.7"},
                        {"id":"network","name":"Network","summary":"Sleepy Wi-Fi"}];
                }
                function searchLauncher(query) { return true; }
                function submitGeocode(query) { return true; }
                function loadCalendar(start, end) { return true; }
                function activateItem(surface, item) { return true; }
                function closeOverviewItem(item) { return true; }
            }
            readonly property QtObject icons: QtObject {}
            Drawers.DailySurfaceView {
                id: dailyView
                anchors.fill: parent
                descriptor: ({"id":"widgets","edge":"right","width":360,
                    "triggerIcon":"icons.calendar","triggerLabel":"Daily widgets",
                    "availability":true,"initialFocusKey":"calendar"})
                screenKey: fixture.screenKey
                surfaceController: fixture.controller
                tokens: fixture.tokens; colors: fixture.colors; effects: fixture.effects
                iconRegistry: fixture.icons; dailyState: fixture.dailyState
            }
            Component.onCompleted: {
                registry.registerDailyDesktop();
                registry.setAvailability("widgets", true);
                controller.open("widgets", screenKey);
            }
        }
    }
    Component { id: osdModelFactory; Services.OsdStreamModel {} }
    Component { id: osdSurfaceFactory; Panels.OsdSurface { width: 280; height: 72 } }

    function test_real_daily_surface_two_outputs_palettes_and_effects_pixels() {
        const dark = createTemporaryObject(surfaceFactory, testCase,
            {"x":0,"screenKey":"DP-1","appearance":"dark","effectsProfile":"full"});
        const light = createTemporaryObject(surfaceFactory, testCase,
            {"x":380,"screenKey":"HDMI-A-1","appearance":"light","effectsProfile":"none"});
        verify(dark && light);
        waitForRendering(dark); waitForRendering(light);
        compare(dark.view.rows.length, 2); compare(light.view.rows.length, 2);
        compare(dark.view.viewState, "ready"); compare(light.view.viewState, "ready");
        const darkImage = grabImage(dark); const lightImage = grabImage(light);
        compare(darkImage.width, 360); compare(lightImage.width, 360);
        verify(darkImage.red(20, 20) < lightImage.red(20, 20));
        verify(dark.effects.glowEnabled); verify(!light.effects.shadowEnabled);
    }

    function test_real_surface_keyboard_focus_and_accessibility_targets() {
        const surface = createTemporaryObject(surfaceFactory, testCase);
        waitForRendering(surface);
        surface.view.listView.forceActiveFocus();
        keyClick(Qt.Key_End);
        compare(surface.view.listView.currentIndex, surface.view.listView.count - 1);
        keyClick(Qt.Key_Home);
        compare(surface.view.listView.currentIndex, 0);
        verify(surface.view.searchField.Accessible.name.length > 0);
        keyClick(Qt.Key_Escape);
        verify(!surface.controller.isOpen("widgets", "DP-1"));
    }

    function test_actual_osd_layer_consumes_two_output_model() {
        const surface = createTemporaryObject(surfaceFactory, testCase);
        const model = createTemporaryObject(osdModelFactory, testCase);
        verify(model.acceptLine(JSON.stringify({"sequence":1,"visible":[
            {"schemaVersion":2,"outputId":"DP-1","kind":"volume","level":0.4,"muted":false,"label":"40%"},
            {"schemaVersion":2,"outputId":"HDMI-A-1","kind":"brightness","level":0.7,"label":"70%"}],
            "overflowByOutput":{"DP-1":1}})));
        const first = createTemporaryObject(osdSurfaceFactory, testCase,
            {"x":0,"osdItem":model.visibleFor("DP-1"),"colors":surface.colors,"effects":surface.effects});
        const second = createTemporaryObject(osdSurfaceFactory, testCase,
            {"x":300,"osdItem":model.visibleFor("HDMI-A-1"),"colors":surface.colors,"effects":surface.effects});
        verify(first !== null && second !== null);
        waitForRendering(first); waitForRendering(second);
        compare(grabImage(first).width, 280); compare(grabImage(second).width, 280);
        compare(model.visibleFor("DP-1").label, "40%");
        compare(model.visibleFor("HDMI-A-1").label, "70%");
        compare(model.overflowFor("DP-1"), 1);
    }
}
