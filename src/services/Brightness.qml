// SPDX-License-Identifier: GPL-3.0-only
// Modified for Sleepy on 2026-08-31: brightness is controlled by sleepy-sessiond.

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Sleepy.Config
import "DesktopCommands.js" as DesktopCommands

Singleton {
    id: root

    readonly property var brightnessCapability: DesktopModel.capabilityData(
        "system", "brightness", {"level": 0.5})
    readonly property list<Monitor> monitors: variants.instances
    property string pendingOutputId: ""
    property var pendingBrightness: null

    function getMonitorForScreen(screen: ShellScreen): var {
        return monitors.find(m => m.modelData === screen);
    }

    function getMonitor(query: string): var {
        if (query === "active")
            return monitors.length ? monitors[0] : null;
        if (query.startsWith("model:")) {
            const model = query.slice(6);
            return monitors.find(m => m.modelData.model === model);
        }
        if (query.startsWith("serial:")) {
            const serial = query.slice(7);
            return monitors.find(m => m.modelData.serialNumber === serial);
        }
        if (query.startsWith("id:")) {
            const id = query.slice(3);
            return monitors.find(m => String(m.modelData.name) === id);
        }
        return monitors.find(m => m.modelData.name === query);
    }

    function increaseBrightness(): void {
        const monitor = root.getMonitor("active");
        if (monitor)
            monitor.setBrightness(monitor.brightness + GlobalConfig.services.brightnessIncrement);
    }

    function decreaseBrightness(): void {
        const monitor = root.getMonitor("active");
        if (monitor)
            monitor.setBrightness(monitor.brightness - GlobalConfig.services.brightnessIncrement);
    }

    Variants {
        id: variants

        model: Quickshell.screens

        Monitor {}
    }

    component Monitor: QtObject {
        id: monitor

        required property ShellScreen modelData
        readonly property real brightness: Math.max(0, Math.min(1, root.brightnessCapability.level ?? 0.5))
        readonly property string outputId: monitor.modelData.name || "active"
        readonly property var pendingBrightness: root.pendingOutputId === outputId ? root.pendingBrightness : null

        function setBrightness(value: real): void {
            value = Math.max(0, Math.min(1, value));
            if (Math.round(brightness * 100) === Math.round(value * 100))
                return;
            const command = DesktopCommands.displaySetBrightness(outputId, value);
            if (command && CommandClient.system(command)) {
                root.pendingOutputId = outputId;
                root.pendingBrightness = value;
            }
        }
    }

    onBrightnessCapabilityChanged: {
        root.pendingOutputId = "";
        root.pendingBrightness = null;
    }

    Connections {
        target: CommandClient
        function onCommandFailed() {
            root.pendingOutputId = "";
            root.pendingBrightness = null;
        }
    }
}
