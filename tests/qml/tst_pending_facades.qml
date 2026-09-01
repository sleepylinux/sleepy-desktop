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

    function test_wallpaper_set_does_not_mutate_confirmed_current_locally() {
        const qml = source("../../src/services/Wallpapers.qml");

        verify(qml.indexOf("readonly property string actualCurrent:") >= 0);
        verify(qml.indexOf("root.pendingWallpaper = path") >= 0);
        verify(qml.indexOf("actualCurrent =") < 0);
        verify(qml.indexOf("root.current =") < 0);
    }

    function test_wallpaper_preview_is_local_pending_state_only() {
        const qml = source("../../src/services/Wallpapers.qml");

        verify(qml.indexOf("readonly property string current: showPreview ? pendingPreview : actualCurrent") >= 0);
        verify(qml.indexOf("root.pendingPreview = path") >= 0);
        verify(qml.indexOf("DesktopCommands.appearancePreviewWallpaper") < 0);
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
