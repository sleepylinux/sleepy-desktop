// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0
import QtTest 1.0
import "../../src/services" as Services
import "../../src/theme" as Theme

TestCase {
    id: testCase
    name: "M3Gallery"
    when: windowShown
    visible: true
    width: 640
    height: 240
    Component { id: osdFactory; Services.OsdStreamModel {} }
    Component {
        id: screenshotFactory
        Item {
            width: 600; height: 180
            Rectangle { x: 0; width: 290; height: 180; color: "#17131f" }
            Rectangle { x: 310; width: 290; height: 180; color: "#f1eef8" }
            Rectangle {
                x: 70; y: 54; width: 150; height: 72; radius: 18; color: "#211c2b"
                Text { anchors.centerIn: parent; text: "DP-1 42%"; color: "#f7f3ff" }
            }
            Rectangle {
                x: 380; y: 54; width: 150; height: 72; radius: 18; color: "#ffffff"
                Text { anchors.centerIn: parent; text: "HDMI-A-1 76%"; color: "#251f2e" }
            }
        }
    }

    function fixture() {
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl("../fixtures/m3-gallery.json"), false);
        request.send();
        return JSON.parse(request.responseText);
    }

    function test_gallery_covers_two_outputs_all_states_and_effect_modes() {
        const data = fixture();
        compare(data.schemaVersion, 1);
        compare(data.outputs.length, 2);
        compare(data.effects.map(function(item) { return item.profile; }).join(","),
                "full,reduced,none");
        ["loading", "offline", "stale", "error", "empty", "ready"].forEach(function(state) {
            verify(data.providerStates.indexOf(state) >= 0);
        });
        compare(data.osd.visible.length, 2);
        compare(data.osd.overflowByOutput["DP-1"], 2);
        compare(data.notification.dnd, true);
    }

    function test_gallery_osd_fixture_matches_production_parser() {
        const model = createTemporaryObject(osdFactory, testCase);
        verify(model.acceptLine(JSON.stringify(fixture().osd)));
        compare(model.visibleFor("DP-1").label, "42%");
        compare(model.visibleFor("HDMI-A-1").label, "76%");
    }

    function test_two_output_gallery_renders_deterministic_distinct_pixels() {
        const canvas = createTemporaryObject(screenshotFactory, testCase);
        verify(canvas !== null);
        waitForRendering(canvas);
        const image = grabImage(canvas);
        compare(image.width, 600);
        compare(image.height, 180);
        verify(image.red(10, 10) < 40 && image.blue(10, 10) < 50);
        verify(image.red(590, 10) > 220 && image.green(590, 10) > 220);
        verify(image.alpha(145, 90) === 255 && image.alpha(455, 90) === 255);
    }
}
