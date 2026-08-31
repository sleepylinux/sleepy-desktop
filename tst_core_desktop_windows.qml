import QtQuick
import Quickshell
import "src/core" as Core

ShellRoot {
    id: root

    readonly property bool virtualOnly:
        Quickshell.env("SLEEPY_TASK7B_HOST_MODE") === "virtual-only"
    property int stage: 0
    property var actualSnapshot: ({})
    property var virtualSnapshot: ({})
    property var retainedVirtualOutput: null
    property int removedVirtualSerial: 0
    property int removedActualSerial: 0
    property int stressIndex: 0
    readonly property int stressCycles: 24
    property int actualStressIndex: 0
    readonly property int actualStressCycles: 4
    property var actualProtocol: null
    property var virtualProtocol: null
    property var actualModel: null
    property var virtualModel: null
    property var actualHost: null
    property var virtualHost: null

    QtObject { id: virtualScreenOne; property string name: "Virtual-Test-1" }
    QtObject { id: virtualScreenTwo; property string name: "Virtual-Test-2" }
    readonly property var virtualScreens: [virtualScreenOne, virtualScreenTwo]

    QtObject {
        id: commandSink
        property bool busy: false
        function system(_command) { return true; }
        function compositor(_command) { return true; }
        function utility(_command) { return true; }
    }

    Component {
        id: virtualBarWindow
        QtObject {
            required property var shellScreen
            required property var outputState
            readonly property var screen: shellScreen
            readonly property bool visible: shellScreen !== null && outputState.barVisible
            readonly property bool focusable: visible
            readonly property int exclusiveZone: outputState.barVisible ? 64 : 0
        }
    }

    Component {
        id: virtualOsdWindow
        QtObject {
            required property var shellScreen
            required property var outputState
            readonly property var screen: shellScreen
            readonly property bool visible: shellScreen !== null && outputState.osdVisible
            readonly property bool focusable: visible
        }
    }

    Component {
        id: hostFactory
        Core.CoreDesktopWindows {}
    }

    function source(relativePath) {
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl(relativePath), false);
        request.send();
        return request.responseText;
    }

    function snapshotForNames(names) {
        const envelope = JSON.parse(source(
            "tests/fixtures/task7b-sdk-full-snapshot.json"));
        const snapshot = envelope.payload.data;
        snapshot.compositor.hyprland.data.monitors = names.map((name, index) => ({
            "id": name, "name": name, "width": 1280, "height": 720,
            "scale": 1, "focused": index === 0
        }));
        snapshot.compositor.hyprland.data.workspaces = names.map((name, index) => ({
            "id": String(index + 1), "name": String(index + 1),
            "monitorId": name, "focused": index === 0
        }));
        snapshot.compositor.hyprland.data.windows = [];
        snapshot.system.osd.data.current = {"schemaVersion": 2,
            "outputId": names[0], "kind": "volume", "level": 0.42,
            "muted": false, "label": "Speakers"};
        return snapshot;
    }

    function accept(protocol, model, snapshot, generation, suffix) {
        if (!protocol.acceptEnvelope({
                "schemaVersion": 3,
                "generation": generation,
                "eventId": "33333333-3333-4333-8333-" + suffix + String(generation).padStart(10, "0"),
                "emittedAt": "2026-08-31T12:00:00Z",
                "cause": {"kind": "lifecycle"},
                "payload": {"type": "fullSnapshot", "data": snapshot}
            }))
            throw new Error("strict-v3 rejection: " + protocol.diagnostic);
        if (!model.applyFullSnapshot(protocol.snapshot, generation))
            throw new Error("projection rejected confirmed snapshot");
    }

    function stressSnapshot(index, included) {
        const snapshot = JSON.parse(JSON.stringify(virtualSnapshot));
        if (included) {
            snapshot.compositor.hyprland.data.monitors[1].id = "stress-" + index;
            snapshot.compositor.hyprland.data.workspaces[1].monitorId = "stress-" + index;
        } else {
            snapshot.compositor.hyprland.data.monitors.pop();
            snapshot.compositor.hyprland.data.workspaces.pop();
        }
        return snapshot;
    }

    function actualSnapshotWithoutMonitor() {
        const snapshot = JSON.parse(JSON.stringify(actualSnapshot));
        snapshot.compositor.hyprland.data.monitors = [];
        snapshot.compositor.hyprland.data.workspaces = [];
        return snapshot;
    }

    function require(condition, message) {
        if (!condition)
            throw new Error(message);
    }

    function outputForName(host, name) {
        for (let index = 0; index < host.outputCount; ++index) {
            const output = host.outputAt(index);
            if (output && output.outputName === name)
                return output;
        }
        return null;
    }

    function runStage() {
        require(Quickshell.screens.length >= 1, "real compositor screen required");
        const actualName = String(Quickshell.screens[0].name);
        if (stage === 0) {
            actualSnapshot = snapshotForNames([actualName]);
            virtualSnapshot = snapshotForNames([virtualScreenOne.name, virtualScreenTwo.name]);
            if (!root.virtualOnly)
                accept(root.actualProtocol, root.actualModel, actualSnapshot, 1, "11");
            accept(root.virtualProtocol, root.virtualModel, virtualSnapshot, 1, "22");
            stage = 1;
        } else if (stage === 1) {
            if (!root.virtualOnly) {
                require(actualHost.outputCount === 1, "real host output missing");
                const actual = outputForName(actualHost, actualName);
                require(actual !== null && actual.shellScreen === Quickshell.screens[0],
                    "real named screen binding mismatch");
                require(actual.barWindow !== null && actual.osdWindow !== null,
                    "default real PanelWindows missing");
                require(actual.barWindow.screen === Quickshell.screens[0], "real bar screen mismatch");
                require(actual.osdWindow.screen === Quickshell.screens[0], "real OSD screen mismatch");
                require(actual.barWindow.visible && actual.barWindow.focusable,
                    "real bar visible/focusable binding mismatch");
                require(actual.barWindow.exclusiveZone === 64, "real bar exclusion mismatch");
                require(actual.osdWindow.visible, "real OSD visible binding mismatch");
            }

            require(virtualHost.outputCount === 2, "two-screen host lifecycle missing");
            retainedVirtualOutput = outputForName(virtualHost, virtualScreenOne.name);
            const removedVirtualOutput = outputForName(virtualHost, virtualScreenTwo.name);
            require(retainedVirtualOutput.shellScreen === virtualScreenOne,
                "first virtual named screen mismatch");
            require(removedVirtualOutput.shellScreen === virtualScreenTwo,
                "second virtual named screen mismatch");
            const fullscreen = JSON.parse(JSON.stringify(virtualSnapshot));
            fullscreen.compositor.hyprland.data.windows = [{"id": "fullscreen",
                "title": "Fullscreen", "applicationId": "test.fullscreen",
                "workspaceId": "1", "focused": true, "fullscreen": true,
                "floating": false, "pinned": false, "grouped": false}];
            accept(root.virtualProtocol, root.virtualModel, fullscreen, 2, "22");
            stage = 2;
        } else if (stage === 2) {
            const first = outputForName(virtualHost, virtualScreenOne.name);
            require(first === retainedVirtualOutput, "fullscreen update recreated output");
            require(!first.barWindow.visible && !first.barWindow.focusable,
                "fullscreen bar window remained interactive");
            require(first.barWindow.exclusiveZone === 0, "fullscreen bar reserved space");
            accept(root.virtualProtocol, root.virtualModel, virtualSnapshot, 3, "22");
            stage = 3;
        } else if (stage === 3) {
            const first = outputForName(virtualHost, virtualScreenOne.name);
            require(first.barWindow.visible && first.barWindow.focusable,
                "bar did not restore after confirmed fullscreen clear");
            require(first.barWindow.exclusiveZone === 64, "bar exclusion did not restore");
            const second = outputForName(virtualHost, virtualScreenTwo.name);
            removedVirtualSerial = second.instanceSerial;
            const removed = JSON.parse(JSON.stringify(virtualSnapshot));
            removed.compositor.hyprland.data.monitors.pop();
            removed.compositor.hyprland.data.workspaces.pop();
            accept(root.virtualProtocol, root.virtualModel, removed, 4, "22");
            stage = 4;
        } else if (stage === 4) {
            require(virtualHost.outputCount === 1, "monitor removal did not remove window pair");
            require(outputForName(virtualHost, virtualScreenOne.name) === retainedVirtualOutput,
                "retained output was recreated on removal");
            accept(root.virtualProtocol, root.virtualModel, virtualSnapshot, 5, "22");
            stage = 5;
        } else if (stage === 5) {
            require(virtualHost.outputCount === 2, "monitor re-add did not restore window pair");
            require(outputForName(virtualHost, virtualScreenOne.name) === retainedVirtualOutput,
                "retained output changed on re-add");
            const readded = outputForName(virtualHost, virtualScreenTwo.name);
            require(readded.instanceSerial
                    !== removedVirtualSerial,
                "removed output identity was reused on re-add");
            const postHotplug = JSON.parse(JSON.stringify(virtualSnapshot));
            postHotplug.compositor.hyprland.data.monitors[0].focused = false;
            postHotplug.compositor.hyprland.data.monitors[1].focused = true;
            postHotplug.compositor.hyprland.data.workspaces[0].focused = false;
            postHotplug.compositor.hyprland.data.workspaces[1].focused = true;
            accept(root.virtualProtocol, root.virtualModel, postHotplug, 6, "22");
            stage = 6;
        } else if (stage === 6) {
            require(virtualHost.outputCount === 2,
                "post-hotplug snapshot changed output count");
            require(outputForName(virtualHost, virtualScreenOne.name) === retainedVirtualOutput,
                "post-hotplug snapshot recreated retained output");
            require(outputForName(virtualHost, virtualScreenTwo.name)
                    .barWindow.outputState.focusedWorkspaceId === "2",
                "post-hotplug confirmed focus did not reach re-added output");
            accept(root.virtualProtocol, root.virtualModel,
                stressSnapshot(stressIndex, true), 7, "22");
            stage = 7;
        } else if (stage === 7) {
            require(virtualHost.outputCount === 2,
                "stress monitor was not instantiated");
            accept(root.virtualProtocol, root.virtualModel,
                stressSnapshot(stressIndex, false), 8 + stressIndex * 2, "22");
            stressIndex += 1;
            stage = 8;
        } else if (stressIndex < stressCycles) {
            require(virtualHost.outputCount === 1,
                "stress monitor was not retired");
            accept(root.virtualProtocol, root.virtualModel,
                stressSnapshot(stressIndex, true), 7 + stressIndex * 2, "22");
            stage = 7;
        } else if (stage === 9) {
            require(actualHost.outputCount === 0,
                "real PanelWindow pair was not retired");
            accept(root.actualProtocol, root.actualModel, actualSnapshot,
                3 + actualStressIndex * 2, "11");
            stage = 10;
        } else if (stage === 10) {
            require(actualHost.outputCount === 1,
                "real PanelWindow pair was not recreated");
            const actual = outputForName(actualHost, actualName);
            require(actual !== null && actual.instanceSerial !== removedActualSerial,
                "real output delegate identity was reused after removal");
            require(actual.shellScreen === Quickshell.screens[0],
                "recreated real output lost its named screen binding");
            require(actual.barWindow !== null && actual.osdWindow !== null,
                "recreated real PanelWindows are missing");
            actualStressIndex += 1;
            if (actualStressIndex < actualStressCycles) {
                removedActualSerial = actual.instanceSerial;
                accept(root.actualProtocol, root.actualModel,
                    actualSnapshotWithoutMonitor(),
                    2 + actualStressIndex * 2, "11");
                stage = 9;
            } else {
                require(actualHost.outputModelCache.length <= 1,
                    "real output model cache grew across lifecycle stress: "
                        + actualHost.outputModelCache.length);
                console.log("TASK7B_HOST_PASS", actualName,
                    virtualScreenOne.name, virtualScreenTwo.name);
                Qt.quit();
                return;
            }
        } else {
            require(virtualHost.outputCount === 1,
                "final stress monitor was not retired");
            require(virtualHost.outputModelCache.length <= 2,
                "retired output model cache grew without bound: "
                    + virtualHost.outputModelCache.length);
            if (!root.virtualOnly) {
                const actual = outputForName(actualHost, actualName);
                require(actual !== null, "real output missing before lifecycle stress");
                removedActualSerial = actual.instanceSerial;
                accept(root.actualProtocol, root.actualModel,
                    actualSnapshotWithoutMonitor(), 2, "11");
                stage = 9;
                stageTimer.restart();
                return;
            }
            console.log("TASK7B_HOST_PASS", actualName,
                virtualScreenOne.name, virtualScreenTwo.name);
            Qt.quit();
            return;
        }
        stageTimer.restart();
    }

    Timer {
        id: stageTimer
        interval: 80
        running: false
        repeat: false
        onTriggered: root.runStage()
    }

    Component.onCompleted: {
        const protocolFactory = Qt.createComponent("src/services/DesktopProtocol.qml");
        const modelFactory = Qt.createComponent("src/services/DesktopModelProjection.qml");
        if (protocolFactory.status !== Component.Ready)
            throw new Error(protocolFactory.errorString());
        if (modelFactory.status !== Component.Ready)
            throw new Error(modelFactory.errorString());
        if (!root.virtualOnly)
            root.actualProtocol = protocolFactory.createObject(root);
        root.virtualProtocol = protocolFactory.createObject(root);
        if (!root.virtualOnly)
            root.actualModel = modelFactory.createObject(root);
        root.virtualModel = modelFactory.createObject(root);
        if (!root.virtualOnly) {
            root.actualHost = hostFactory.createObject(root, {
                "desktopModel": root.actualModel,
                "commandClient": commandSink,
                "tokens": ({"motionDuration": 0})
            });
        }
        root.virtualHost = hostFactory.createObject(root, {
            "desktopModel": root.virtualModel,
            "commandClient": commandSink,
            "tokens": ({"motionDuration": 0}),
            "screens": root.virtualScreens,
            "barWindowComponent": virtualBarWindow,
            "osdWindowComponent": virtualOsdWindow
        });
        if ((!root.virtualOnly && !root.actualHost) || !root.virtualHost)
            throw new Error("production CoreDesktopWindows host creation failed");
        stageTimer.start();
    }
}
