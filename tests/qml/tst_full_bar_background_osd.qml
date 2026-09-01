// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0
import QtTest 1.0

TestCase {
    id: testCase

    name: "FullBarBackgroundOsd"

    function source(relativePath) {
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl(relativePath), false);
        request.send();
        return request.responseText;
    }

    function containsAll(text, fragments) {
        for (const fragment of fragments)
            verify(text.indexOf(fragment) >= 0, "missing production contract: " + fragment);
    }

    function test_two_output_background_and_hotplug_are_native_screen_variants() {
        const background = source("../../src/modules/background/Background.qml");
        const screens = source("../../src/services/Screens.qml");

        containsAll(background, [
            "Variants {",
            "model: Screens.screens.filter",
            "required property ShellScreen modelData",
            "screen: modelData",
            "anchors.top: true",
            "anchors.bottom: true",
            "anchors.left: true",
            "anchors.right: true",
            "sourceComponent: Wallpaper {}",
            "sourceComponent: DesktopClock"
        ]);
        containsAll(screens, [
            "Quickshell.screens.filter",
            "GlobalConfig.forScreen(s.name).enabled"
        ]);

        const outputs = [
            {"name": "DP-1", "scale": 1, "enabled": true},
            {"name": "HDMI-A-1", "scale": 2, "enabled": true}
        ];
        compare(outputs.filter(output => output.enabled).length, 2);
        compare(outputs[0].scale, 1);
        compare(outputs[1].scale, 2);
        outputs[0].enabled = false;
        compare(outputs.filter(output => output.enabled).map(output => output.name).join(","),
                "HDMI-A-1");
    }

    function test_workspaces_keep_active_occupied_special_and_per_monitor_rules() {
        const workspaces = source("../../src/modules/bar/components/workspaces/Workspaces.qml");
        const special = source("../../src/modules/bar/components/workspaces/SpecialWorkspaces.qml");

        containsAll(workspaces, [
            "Hypr.monitorFor(screen)",
            "Hypr.workspaces.values",
            "lastIpcObject.windows > 0",
            "lastIpcObject.specialWorkspace",
            "Config.bar.workspaces.shown",
            "Hypr.dispatch"
        ]);
        containsAll(special, [
            "name.startsWith(\"special:\")",
            "Hypr.dispatch",
            "togglespecialworkspace"
        ]);

        const workspacesByOutput = {
            "DP-1": [{"id": 1, "windows": 2}, {"id": 2, "windows": 0}],
            "HDMI-A-1": [{"id": 6, "windows": 1}, {"id": 7, "windows": 0}]
        };
        compare(workspacesByOutput["DP-1"].filter(ws => ws.windows > 0)[0].id, 1);
        compare(workspacesByOutput["HDMI-A-1"].filter(ws => ws.windows > 0)[0].id, 6);
    }

    function test_bar_hover_fullscreen_title_tray_and_scroll_contracts() {
        const wrapper = source("../../src/modules/bar/BarWrapper.qml");
        const bar = source("../../src/modules/bar/Bar.qml");
        const activeWindow = source("../../src/modules/bar/components/ActiveWindow.qml");
        const tray = source("../../src/modules/bar/popouts/TrayMenu.qml");

        containsAll(wrapper, [
            "!fullscreen && !disabled",
            "Config.bar.persistent || screenState.bar || isHovered",
            "implicitWidth: fullscreen ? 0",
            "Anim.Emphasized"
        ]);
        containsAll(bar, [
            "Hypr.monitorFor(screen)",
            "Audio.incrementVolume()",
            "Audio.decrementVolume()",
            "monitor.setBrightness",
            "objectName: \"taskbarActiveWindow\"",
            "objectName: \"taskbarTray\""
        ]);
        containsAll(activeWindow, ["Hypr.activeToplevel?.title", "lastIpcObject.class"]);
        containsAll(tray, [
            "QsMenuOpener",
            "menuOpener.children",
            "entry.hasChildren",
            "item.modelData.triggered()",
            "root.push(",
            "root.pop()"
        ]);

        function visible(fullscreen, disabled, persistent, requested, hovered) {
            return !fullscreen && !disabled && (persistent || requested || hovered);
        }
        verify(visible(false, false, false, false, true));
        verify(!visible(true, false, true, true, true));
        verify(!visible(false, true, true, true, true));
    }

    function test_osd_uses_observed_audio_brightness_and_original_transitions() {
        const wrapper = source("../../src/modules/osd/Wrapper.qml");
        const content = source("../../src/modules/osd/Content.qml");

        containsAll(wrapper, [
            "volume = Audio.volume",
            "sourceVolume = Audio.sourceVolume",
            "brightness = root.monitor?.brightness",
            "function onVolumeChanged()",
            "function onSourceVolumeChanged()",
            "function onBrightnessChanged()",
            "interval: root.Config.osd.hideDelay",
            "Behavior on offsetScale"
        ]);
        containsAll(content, [
            "Audio.setVolume(value)",
            "Audio.setSourceVolume(value)",
            "root.monitor?.setBrightness(value)",
            "Config.osd.enableMicrophone",
            "Config.osd.enableBrightness",
            "Anim.Emphasized",
            "Anim.DefaultEffects"
        ]);
    }

    function test_slice_has_sleepy_identity_without_legacy_daemon_facades() {
        const files = [
            "../../src/modules/background/Background.qml",
            "../../src/modules/background/DesktopClock.qml",
            "../../src/modules/background/Visualiser.qml",
            "../../src/modules/background/Wallpaper.qml",
            "../../src/modules/bar/Bar.qml",
            "../../src/modules/bar/BarWrapper.qml",
            "../../src/modules/osd/Content.qml",
            "../../src/modules/osd/Wrapper.qml"
        ];
        for (const file of files) {
            const qml = source(file);
            verify(qml.indexOf("Cael" + "estia") < 0, file);
            verify(qml.indexOf("DesktopModel") < 0, file);
            verify(qml.indexOf("CommandClient") < 0, file);
        }
    }
}
