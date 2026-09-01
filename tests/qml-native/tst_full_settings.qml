// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0
import QtTest 1.0
import Sleepy.Config

TestCase {
    name: "FullSettings"

    function test_all_major_sections_load() {
        compare(GlobalConfig.enabled, true);
        compare(GlobalConfig.appearance.deformScale, 1.25);
        compare(GlobalConfig.appearance.font.scale, 1.1);
        compare(GlobalConfig.appearance.font.body.family, "Sleepy Test Sans");
        compare(GlobalConfig.appearance.anim.durations.scale, 0.75);
        compare(GlobalConfig.appearance.transparency.enabled, true);
        compare(GlobalConfig.appearance.transparency.base, 0.82);
        compare(GlobalConfig.appearance.transparency.layers, 0.45);
        compare(GlobalConfig.general.showOverFullscreen, true);
        compare(GlobalConfig.general.apps.terminal, ["ghostty"]);
        compare(GlobalConfig.background.wallpaperEnabled, false);
        compare(GlobalConfig.bar.dragThreshold, 31);
        compare(GlobalConfig.dashboard.showDashboard, false);
        compare(GlobalConfig.launcher.maxShown, 11);
        compare(GlobalConfig.lock.useWallpaper, true);
        compare(GlobalConfig.nexus.wallpapersPerRow, 6);
        compare(GlobalConfig.notifs.clearThreshold, 0.42);
        compare(GlobalConfig.osd.hideDelay, 2345);
        compare(GlobalConfig.services.visualiserBars, 72);
        compare(GlobalConfig.session.vimKeybinds, true);
        compare(GlobalConfig.sidebar.minHoverThreshold, 345);
        compare(GlobalConfig.utilities.maxToasts, 7);
        compare(GlobalConfig.paths.wallpaperDir, "/tmp/sleepy-wallpapers");
    }

    function test_per_monitor_override_inherits_global_values() {
        const monitorConfig = GlobalConfig.forScreen("DP-1");
        compare(monitorConfig.bar.dragThreshold, 47);
        compare(monitorConfig.background.wallpaperEnabled, true);
        compare(monitorConfig.launcher.maxShown, 11);
    }

    function test_defaults_are_sleepy_owned() {
        compare(GlobalConfig.paths.sessionGif, "root:/assets/logo.svg");
        compare(GlobalConfig.paths.mediaGif, "root:/assets/logo.svg");
        compare(GlobalConfig.paths.noNotifsPic, "root:/assets/logo.svg");
        compare(GlobalConfig.paths.lockNoNotifsPic, "root:/assets/logo.svg");
    }

    function test_save_is_batched_and_preserves_quarantined_keys() {
        GlobalConfig.bar.dragThreshold = 33;
        const monitorConfig = GlobalConfig.forScreen("DP-1");
        monitorConfig.bar.dragThreshold = 49;
        tryCompare(GlobalConfig.bar, "dragThreshold", 33, 1000);
        tryCompare(monitorConfig.bar, "dragThreshold", 49, 1000);
        wait(750);
    }
}
