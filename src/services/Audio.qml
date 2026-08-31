// SPDX-License-Identifier: GPL-3.0-only
// Modified for Sleepy on 2026-08-31: audio state and mutations are daemon-owned.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Sleepy.Config

Singleton {
    id: root

    readonly property var audioCapability: DesktopModel.capabilityData(
        "system", "audio", {"nodes": [], "streams": [], "visualiser": [], "meters": {}})
    readonly property list<var> sinks: audioNodes("output")
    readonly property list<var> sources: audioNodes("input")
    readonly property list<var> streams: (audioCapability.streams || []).map(streamNode)
    readonly property var sink: sinks.find(node => node.isDefault) || (sinks.length ? sinks[0] : null)
    readonly property var source: sources.find(node => node.isDefault) || (sources.length ? sources[0] : null)
    readonly property bool muted: Boolean(sink?.audio?.muted)
    readonly property real volume: numberOr(sink?.audio?.volume, 0)
    readonly property bool sourceMuted: Boolean(source?.audio?.muted)
    readonly property real sourceVolume: numberOr(source?.audio?.volume, 0)
    readonly property alias cava: cava
    readonly property alias beatTracker: beatTracker

    function numberOr(value: var, fallback: real): real {
        return Number.isFinite(value) ? value : fallback;
    }

    function clampVolume(value: real): real {
        return Math.max(0, Math.min(GlobalConfig.services.maxVolume, value));
    }

    function audioNodes(kind: string): list<var> {
        return (audioCapability.nodes || [])
            .filter(node => node.kind === kind)
            .map(node => audioNode(node));
    }

    function audioNode(node: var): var {
        const volume = root.numberOr(node.volume, 0);
        const muted = Boolean(node.muted);
        return {
            "id": node.id || node.name || "",
            "name": node.name || node.description || node.id || "",
            "description": node.description || node.name || node.id || qsTr("Unknown Device"),
            "ready": node.ready ?? true,
            "isSink": node.kind === "output",
            "isStream": false,
            "isDefault": Boolean(node.isDefault),
            "properties": node.properties || {},
            "audio": {
                "volume": volume,
                "muted": muted
            }
        };
    }

    function streamNode(node: var): var {
        const mapped = root.audioNode(Object.assign({"kind": "stream"}, node));
        mapped.isStream = true;
        mapped.applicationName = node.applicationName || mapped.properties["application.name"] || mapped.name;
        return mapped;
    }

    function nodeId(node: var): string {
        return node?.id || node?.name || "";
    }

    function setVolume(newVolume: real): bool {
        if (!root.sink)
            return false;
        return CommandClient.system({
            "domain": "audio",
            "action": {
                "type": "setOutputVolume",
                "data": {"nodeId": root.nodeId(root.sink), "volume": root.clampVolume(newVolume)}
            }
        });
    }

    function incrementVolume(amount: real): bool {
        return root.setVolume(root.volume + (amount || GlobalConfig.services.audioIncrement));
    }

    function decrementVolume(amount: real): bool {
        return root.setVolume(root.volume - (amount || GlobalConfig.services.audioIncrement));
    }

    function setSourceVolume(newVolume: real): bool {
        if (!root.source)
            return false;
        return CommandClient.system({
            "domain": "audio",
            "action": {
                "type": "setInputVolume",
                "data": {"nodeId": root.nodeId(root.source), "volume": root.clampVolume(newVolume)}
            }
        });
    }

    function incrementSourceVolume(amount: real): bool {
        return root.setSourceVolume(root.sourceVolume + (amount || GlobalConfig.services.audioIncrement));
    }

    function decrementSourceVolume(amount: real): bool {
        return root.setSourceVolume(root.sourceVolume - (amount || GlobalConfig.services.audioIncrement));
    }

    function setAudioSink(newSink: var): bool {
        const id = root.nodeId(newSink);
        if (!id.length)
            return false;
        return CommandClient.system({
            "domain": "audio",
            "action": {"type": "setDefaultOutput", "data": {"nodeId": id}}
        });
    }

    function setAudioSource(newSource: var): bool {
        const id = root.nodeId(newSource);
        if (!id.length)
            return false;
        return CommandClient.system({
            "domain": "audio",
            "action": {"type": "setDefaultInput", "data": {"nodeId": id}}
        });
    }

    function cycleNextAudioOutput(): bool {
        if (root.sinks.length === 0)
            return false;
        const currentIndex = root.sinks.findIndex(node => root.nodeId(node) === root.nodeId(root.sink));
        const nextIndex = (currentIndex + 1) % root.sinks.length;
        return root.setAudioSink(root.sinks[nextIndex]);
    }

    function setStreamVolume(stream: var, newVolume: real): bool {
        const id = root.nodeId(stream);
        if (!id.length)
            return false;
        return CommandClient.system({
            "domain": "audio",
            "action": {
                "type": "setStreamVolume",
                "data": {"streamId": id, "volume": root.clampVolume(newVolume)}
            }
        });
    }

    function setStreamMuted(stream: var, muted: bool): bool {
        const id = root.nodeId(stream);
        if (!id.length)
            return false;
        return CommandClient.system({
            "domain": "audio",
            "action": {
                "type": "setStreamMuted",
                "data": {"streamId": id, "muted": Boolean(muted)}
            }
        });
    }

    function getStreamVolume(stream: var): real {
        return root.numberOr(stream?.audio?.volume, 0);
    }

    function getStreamMuted(stream: var): bool {
        return Boolean(stream?.audio?.muted);
    }

    function getStreamName(stream: var): string {
        if (!stream)
            return qsTr("Unknown");
        return stream.applicationName || stream.properties?.["application.name"]
            || stream.description || stream.name || qsTr("Unknown Application");
    }

    QtObject {
        id: cava

        readonly property list<real> values: root.audioCapability.visualiser || []
        readonly property int bars: GlobalConfig.services.visualiserBars
    }

    QtObject {
        id: beatTracker

        readonly property real bpm: root.numberOr(root.audioCapability.meters?.bpm, 0)
    }

    IpcHandler {
        function cycleOutput(): void {
            root.cycleNextAudioOutput();
        }

        target: "audio"
    }
}
