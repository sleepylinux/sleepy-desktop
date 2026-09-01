import QtQuick 6.0
import QtTest 1.0

TestCase {
    id: testCase

    name: "PendingFacades"

    function source(relativePath) {
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl(relativePath), false);
        request.send();
        return request.responseText;
    }

    function test_wallpaper_set_updates_direct_state_and_invokes_sleepy_helper() {
        const qml = source("../../src/services/Wallpapers.qml");

        verify(qml.indexOf("property string actualCurrent") >= 0);
        verify(qml.indexOf("actualCurrent = path") >= 0);
        verify(qml.indexOf('["sleepy", "wallpaper", "-f", path') >= 0);
        verify(qml.indexOf("DesktopCommands") < 0);
    }

    function test_wallpaper_preview_is_local_pending_state_only() {
        const qml = source("../../src/services/Wallpapers.qml");

        verify(qml.indexOf("readonly property string current: showPreview ? previewPath : actualCurrent") >= 0);
        verify(qml.indexOf("previewPath = path") >= 0);
        verify(qml.indexOf("Colours.showPreview = true") >= 0);
    }

    function test_brightness_set_tracks_pending_without_mutating_confirmed_level() {
        const qml = source("../../src/services/Brightness.qml");
        const setter = qml.slice(qml.indexOf("function setBrightness(value: real)"),
                                 qml.indexOf("function initBrightness()"));

        verify(qml.indexOf("property real requestedBrightness: NaN") >= 0);
        verify(setter.indexOf("requestedBrightness = value") >= 0);
        verify(setter.indexOf("brightness = value") < 0);
        verify(setter.indexOf("monitor.brightness =") < 0);
        verify(qml.indexOf("monitor.initBrightness()") >= 0);
    }
}
