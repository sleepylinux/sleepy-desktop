// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0
import QtTest 1.0

TestCase {
    id: testCase

    name: "FullLauncherDrawersWindowInfo"

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

    function test_launcher_keyboard_search_apps_and_failure_safe_execution() {
        const content = source("../../src/modules/launcher/Content.qml");
        const apps = source("../../src/modules/launcher/services/Apps.qml");
        const appList = source("../../src/modules/launcher/AppList.qml");

        containsAll(content, [
            "Keys.onUpPressed",
            "Keys.onDownPressed",
            "Keys.onEscapePressed",
            "GlobalConfig.launcher.vimKeybinds",
            "Qt.Key_J",
            "Qt.Key_K",
            "Qt.Key_Tab",
            "screenState.launcher = false"
        ]);
        containsAll(apps, [
            "DesktopEntries.applications.values",
            "GlobalConfig.launcher.hiddenApps",
            "favouriteApps: GlobalConfig.launcher.favouriteApps",
            "Quickshell.execDetached({",
            "workingDirectory: entry.workingDirectory"
        ]);
        containsAll(appList, [
            "Apps.search(text)",
            "case \"calc\"",
            "Schemes.query(text)",
            "M3Variants.query(text)"
        ]);
    }

    function test_calculator_copy_and_terminal_are_fixed_argv() {
        const calc = source("../../src/modules/launcher/items/CalcItem.qml");
        containsAll(calc, [
            "CUtils.copyTextToClipboard(Qalculator.rawResult)",
            "[...GlobalConfig.general.apps.terminal, \"qalc\", \"-i\", root.math]"
        ]);
        verify(calc.indexOf("-C") < 0);
        verify(calc.indexOf("sh\"") < 0);
    }

    function test_scheme_wallpaper_and_preview_keep_original_launcher_composition() {
        const schemes = source("../../src/modules/launcher/services/Schemes.qml");
        const variants = source("../../src/modules/launcher/services/M3Variants.qml");
        const wallpapers = source("../../src/services/Wallpapers.qml");
        const list = source("../../src/modules/launcher/WallpaperList.qml");

        containsAll(schemes, ["scheme", "list", "currentScheme", "component Scheme"]);
        containsAll(variants, ["vibrant", "tonalspot", "expressive", "monochrome"]);
        containsAll(wallpapers, [
            "function setWallpaper(path: string)",
            "function preview(path: string)",
            "function stopPreview()",
            "FileSystemModel",
            "Paths.wallsdir",
            "[\"sleepy\", \"wallpaper\", \"-f\", path"
        ]);
        containsAll(list, ["Wallpapers.preview(", "Wallpapers.stopPreview()"]);
    }

    function test_drawer_drag_thresholds_route_each_original_surface() {
        const interactions = source("../../src/modules/drawers/Interactions.qml");
        const window = source("../../src/modules/drawers/ContentWindow.qml");
        containsAll(interactions, [
            "Config.bar.dragThreshold",
            "Config.session.dragThreshold",
            "Config.sidebar.dragThreshold",
            "Config.launcher.dragThreshold",
            "Config.dashboard.dragThreshold",
            "screenState.launcher",
            "screenState.dashboard",
            "screenState.sidebar",
            "screenState.session"
        ]);
        containsAll(window, ["dragMaskPadding", "Math.max(...thresholds)"]);
    }

    function test_window_preview_and_actions_use_native_hyprland_objects() {
        const preview = source("../../src/modules/windowinfo/Preview.qml");
        const buttons = source("../../src/modules/windowinfo/Buttons.qml");
        containsAll(preview, [
            "required property HyprlandToplevel client",
            "ScreencopyView",
            "captureSource: root.client?.wayland",
            "live: true",
            "constraintSize.width"
        ]);
        containsAll(buttons, [
            "movetoworkspace",
            "togglefloating",
            "pin address:",
            "killwindow",
            "Hypr.dispatch"
        ]);
        verify(preview.indexOf("Preview unavailable") < 0);
    }

    function test_area_picker_uses_hypr_cursor_and_constrained_native_capture() {
        const picker = source("../../src/modules/areapicker/Picker.qml");
        containsAll(picker, [
            "[\"hyprctl\", \"cursorpos\", \"-j\"]",
            "CUtils.copyItemToClipboard(screencopy, selectionRect",
            "CUtils.saveItemToTemp(screencopy, selectionRect",
            "[\"swappy\", \"-f\", path]",
            "Keys.onEscapePressed",
            "Hypr.toplevelsForWs"
        ]);
        verify(picker.indexOf("CommandClient.utility") < 0);
        verify(picker.indexOf("sh\", \"-c") < 0);
    }
}
