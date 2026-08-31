// SPDX-License-Identifier: GPL-3.0-only
// Modified for Sleepy on 2026-08-31: media players are daemon-published.

pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import Sleepy
import Sleepy.Config
import qs.components.misc

Singleton {
    id: root

    readonly property var mediaCapability: DesktopModel.capabilityData(
        "system", "media", {"players": []})
    readonly property list<var> list: (mediaCapability.players || []).map(playerRecord)
    property var manualActive: null
    readonly property var active: root.manualActive
        || root.list.find(player => root.getIdentity(player) === GlobalConfig.services.defaultPlayer)
        || (root.list.length ? root.list[0] : null)
    property string lastNowPlayingKey: ""

    function playerRecord(player: var): var {
        const id = player.id || player.identity || player.name || "";
        return Object.assign({
            "id": id,
            "uniqueId": id,
            "identity": player.identity || player.name || id,
            "trackTitle": player.title || player.trackTitle || "",
            "trackArtist": player.artist || player.trackArtist || "",
            "trackAlbum": player.album || player.trackAlbum || "",
            "trackArtUrl": player.artUrl || player.trackArtUrl || "",
            "metadata": player.metadata || {},
            "position": Number.isFinite(player.position) ? player.position : 0,
            "length": Number.isFinite(player.length) ? player.length : 0,
            "isPlaying": Boolean(player.playing || player.isPlaying),
            "canPlay": player.canPlay ?? true,
            "canPause": player.canPause ?? true,
            "canTogglePlaying": player.canTogglePlaying ?? true,
            "canGoPrevious": player.canGoPrevious ?? true,
            "canGoNext": player.canGoNext ?? true,
            "canSeek": player.canSeek ?? false,
            "shuffle": Boolean(player.shuffle),
            "shuffleSupported": player.shuffleSupported ?? false,
            "loopState": player.loopState ?? 0,
            "loopSupported": player.loopSupported ?? false,
            "play": function() { root.control(id, "play"); },
            "pause": function() { root.control(id, "pause"); },
            "togglePlaying": function() { root.control(id, "toggle"); },
            "previous": function() { root.control(id, "previous"); },
            "next": function() { root.control(id, "next"); },
            "stop": function() { root.control(id, "stop"); },
            "positionChanged": function() {}
        }, player);
    }

    function getIdentity(player: var): string {
        if (!player)
            return "";
        const alias = GlobalConfig.services.playerAliases.find(a => a.from === player.identity);
        return alias?.to ?? player.identity;
    }

    function getArtUrl(player: var): string {
        if (!player)
            return "";
        if (player.trackArtUrl)
            return player.trackArtUrl;

        const url = player.metadata?.["xesam:url"] ?? "";
        if (url.startsWith("https://www.youtube.com/watch")) {
            const id = url.match(/[?&]v=([\w-]{11})/)?.[1];
            return id ? `https://img.youtube.com/vi/${id}/hqdefault.jpg` : "";
        }
        return "";
    }

    function control(playerId: string, type: string, data: var): bool {
        return CommandClient.system({
            "domain": "media",
            "action": {
                "type": type,
                "data": Object.assign({"playerId": playerId}, data || {})
            }
        });
    }

    function maybeToastNowPlaying(): void {
        if (!GlobalConfig.utilities.toasts.nowPlaying)
            return;
        const player = root.active;
        if (!player || !player.trackTitle || !player.trackArtist)
            return;
        const key = `${root.getIdentity(player)}\0${player.uniqueId}\0${player.trackTitle}\0${player.trackArtist}`;
        if (key === root.lastNowPlayingKey)
            return;
        root.lastNowPlayingKey = key;
        Toaster.toast(qsTr("Now Playing"), qsTr("%1 - %2").arg(player.trackArtist).arg(player.trackTitle), "music_note");
    }

    onActiveChanged: {
        root.lastNowPlayingKey = "";
        root.maybeToastNowPlaying();
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaToggle"
        description: "Toggle media playback"
        onPressed: root.active?.togglePlaying()
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaPrev"
        description: "Previous track"
        onPressed: root.active?.previous()
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaNext"
        description: "Next track"
        onPressed: root.active?.next()
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaStop"
        description: "Stop media playback"
        onPressed: root.active?.stop()
    }

    IpcHandler {
        function getActive(prop: string): string {
            const active = root.active;
            return active ? active[prop] ?? "Invalid property" : "No active player";
        }

        function list(): string {
            return root.list.map(p => root.getIdentity(p)).join("\n");
        }

        function play(): void {
            root.active?.play();
        }

        function pause(): void {
            root.active?.pause();
        }

        function playPause(): void {
            root.active?.togglePlaying();
        }

        function previous(): void {
            root.active?.previous();
        }

        function next(): void {
            root.active?.next();
        }

        function stop(): void {
            root.active?.stop();
        }

        target: "mpris"
    }
}
