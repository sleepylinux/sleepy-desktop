// SPDX-License-Identifier: GPL-3.0-only
// Modified for Sleepy on 2026-08-31: wallpaper inventory and persistence are daemon-owned.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Sleepy.Config
import qs.services

Searcher {
    id: root

    readonly property var appearanceState: DesktopModel.appearance || ({})
    readonly property string fallback: Quickshell.shellPath("assets/wallpaper.webp")
    property bool showPreview: false
    readonly property string current: showPreview ? previewPath : actualCurrent
    property string previewPath
    property string actualCurrent: appearanceState.wallpaperId || appearanceState.wallpaperPath || fallback
    property bool previewColourLock: false
    property bool pendingPreviewClear: false

    function wallpaperRecords(): list<var> {
        return (appearanceState.wallpapers || []).map(wallpaper => Object.assign({
            "id": wallpaper.id || wallpaper.path || "",
            "path": wallpaper.path || wallpaper.id || "",
            "relativePath": wallpaper.relativePath || wallpaper.name || wallpaper.id || wallpaper.path || "",
            "name": wallpaper.name || wallpaper.relativePath || wallpaper.id || "",
            "parentDir": wallpaper.parentDir || wallpaper.category || ""
        }, wallpaper));
    }

    function getCategoryFor(w: var): string {
        const category = w?.category || w?.parentDir || "";
        if (!category || category.indexOf("/") < 0)
            return category;
        return category.slice(0, category.indexOf("/"));
    }

    function setRandom(): bool {
        const entries = root.list || [];
        if (!entries.length)
            return false;
        return root.setWallpaper(entries[Math.floor(Math.random() * entries.length)].path);
    }

    function setWallpaper(path: string): bool {
        if (!path || path.length === 0)
            return false;
        root.actualCurrent = path;
        return CommandClient.appearance({
            "type": "setWallpaper",
            "data": {"wallpaperId": path}
        });
    }

    function preview(path: string): bool {
        root.previewPath = path;
        root.showPreview = true;
        return CommandClient.appearance({
            "type": "previewWallpaper",
            "data": {"wallpaperId": path}
        });
    }

    function stopPreview(): bool {
        root.showPreview = false;
        Colours.showPreview = false;
        return CommandClient.appearance({"type": "stopWallpaperPreview"});
    }

    list: wallpaperRecords()
    key: "relativePath"
    useFuzzy: GlobalConfig.launcher.useFuzzy.wallpapers
    extraOpts: useFuzzy ? ({}) : ({forward: false})

    IpcHandler {
        function get(): string {
            return root.actualCurrent;
        }

        function set(path: string): void {
            root.setWallpaper(path);
        }

        function list(): string {
            return root.list.map(w => w.path).join("\n");
        }

        target: "wallpaper"
    }
}
