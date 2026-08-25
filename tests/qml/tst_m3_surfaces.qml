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
            property string surfaceKind: "widgets"
            property bool portalDark: true
            property var customColors: null
            readonly property alias view: dailyView
            readonly property Theme.EffectsPolicy effects: Theme.EffectsPolicy {
                effectsProfile: fixture.effectsProfile
            }
            readonly property Theme.Palette colors: Theme.Palette {
                appearanceMode: fixture.appearance
                portalDark: fixture.portalDark
                customColors: fixture.customColors
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
                property QtObject notifications: QtObject {
                    property bool dnd: false
                    property int refreshCalls: 0
                    property int dndCalls: 0
                    property int actionCalls: 0
                    property string lastActionId: ""
                    function refresh() { refreshCalls += 1; return true; }
                    function setDnd(value) { dnd = value; dndCalls += 1; return true; }
                    function invokeAction(id, actionId) { actionCalls += 1; lastActionId = actionId; return true; }
                    function markRead(id) { return true; }
                    function dismiss(id) { return true; }
                }
                function stateFor(id) { return "ready"; }
                function itemsFor(id) {
                    if (id === "notifications") return [{"id":7,"summary":"Build finished",
                        "actions":[{"id":"open","label":"Open","state":"available"},
                            {"id":"details","label":"Details","state":"available"}]}];
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
                descriptor: ({"id":fixture.surfaceKind,"edge":"right","width":360,
                    "triggerIcon":fixture.surfaceKind === "notifications" ? "icons.notification" : "icons.calendar",
                    "triggerLabel":fixture.surfaceKind === "notifications" ? "Notifications" : "Daily widgets",
                    "availability":true,"initialFocusKey":"calendar"})
                screenKey: fixture.screenKey
                surfaceController: fixture.controller
                tokens: fixture.tokens; colors: fixture.colors; effects: fixture.effects
                iconRegistry: fixture.icons; dailyState: fixture.dailyState
            }
            Component.onCompleted: {
                registry.registerDailyDesktop();
                registry.setAvailability(surfaceKind, true);
                controller.open(surfaceKind, screenKey);
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
        compare(dark.view.displayLabel({"id":"internal-id","displayName":"Prague"}), "Prague");
        compare(dark.view.displayLabel({"id":"internal-id","summary":"CPU 18%"}), "CPU 18%");
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

    function test_notification_controls_and_each_action_are_keyboard_reachable() {
        const surface = createTemporaryObject(surfaceFactory, testCase,
            {"surfaceKind":"notifications"});
        waitForRendering(surface);
        surface.view.listView.forceLayout();
        tryVerify(function() { return surface.view.listView.itemAtIndex(0) !== null; });
        const notification = surface.view.listView.itemAtIndex(0);
        compare(notification.actionRepeater.count, 2);
        const refresh = findChild(surface, "dailyRefreshButton");
        const dnd = findChild(surface, "dailyDndButton");
        const open = notification.actionRepeater.itemAt(0);
        const details = notification.actionRepeater.itemAt(1);
        verify(refresh !== null, "refresh control missing");
        verify(dnd !== null, "DND control missing");
        verify(open !== null, "open action missing");
        verify(details !== null, "details action missing");
        surface.dailyState.notifications.refreshCalls = 0;
        verify(refresh.activeFocusOnTab && dnd.activeFocusOnTab
            && open.activeFocusOnTab && details.activeFocusOnTab);
        refresh.forceActiveFocus(); keyClick(Qt.Key_Return);
        compare(surface.dailyState.notifications.refreshCalls, 1);
        keyClick(Qt.Key_Tab); tryVerify(function() { return dnd.activeFocus; });
        keyClick(Qt.Key_Space);
        compare(surface.dailyState.notifications.dndCalls, 1);
        open.forceActiveFocus(); keyClick(Qt.Key_Return);
        compare(surface.dailyState.notifications.lastActionId, "open");
        details.forceActiveFocus(); keyClick(Qt.Key_Space);
        compare(surface.dailyState.notifications.lastActionId, "details");
        compare(surface.dailyState.notifications.actionCalls, 2);
    }

    function test_builtin_system_palette_pixels_follow_portal_despite_dark_document_colors() {
        const darkDocument = {"background":"#111111","surface":"#222222",
            "textPrimary":"#eeeeee","textSecondary":"#cccccc","accent":"#b9a7ff","control":"#76c7aa"};
        const light = createTemporaryObject(surfaceFactory, testCase,
            {"x":0,"appearance":"system","portalDark":false,"effectsProfile":"none","customColors":darkDocument});
        const dark = createTemporaryObject(surfaceFactory, testCase,
            {"x":380,"appearance":"system","portalDark":true,"effectsProfile":"none","customColors":darkDocument});
        waitForRendering(light); waitForRendering(dark);
        compare(light.colors.shellBackground.toString(), "#f1eef8");
        compare(dark.colors.shellBackground.toString(), "#17131f");
        verify(grabImage(light).red(20, 20) > grabImage(dark).red(20, 20));
    }
}
