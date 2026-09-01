// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0
import QtTest 1.0

TestCase {
    id: testCase
    name: "CoreDesktopSurfaces"
    width: 720
    height: 520

    Component {
        id: commandSinkFactory
        QtObject {
            property bool busy: false
            property var sent: []
            function system(command) {
                sent = sent.concat([{"family": "system", "command": command}]);
                return true;
            }
            function compositor(command) {
                sent = sent.concat([{"family": "compositor", "command": command}]);
                return true;
            }
            function utility(command) {
                sent = sent.concat([{"family": "utility", "command": command}]);
                return true;
            }
            function session(command) {
                sent = sent.concat([{"family": "session", "command": command}]);
                return true;
            }
        }
    }

    function source(relativePath) {
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl(relativePath), false);
        request.send();
        return request.responseText;
    }

    function fixtureSnapshot() {
        const envelope = JSON.parse(source(
            "../../../sleepy-sdk/fixtures/desktop-runtime/full-snapshot.json"));
        const snapshot = envelope.payload.data;
        const hyprland = snapshot.compositor.hyprland.data;
        hyprland.monitors.push({"id": "HDMI-A-1", "name": "HDMI-A-1",
            "width": 1920, "height": 1080, "scale": 2, "focused": false});
        hyprland.workspaces.push(
            {"id": "special-music", "name": "special:music", "monitorId": "DP-1", "focused": false},
            {"id": "2", "name": "2", "monitorId": "HDMI-A-1", "focused": false},
            {"id": "3", "name": "3", "monitorId": "HDMI-A-1", "focused": false});
        hyprland.windows.push({"id": "window-two", "title": "Browser",
            "applicationId": "org.browser", "workspaceId": "2", "focused": false,
            "fullscreen": true, "floating": false, "pinned": false, "grouped": false});
        snapshot.utilities.trayItems.data = [{
            "id": "tray-network", "title": "Network", "menu": {
                "id": "menu-root", "label": "Network", "enabled": true,
                "children": [{"id": "menu-status", "label": "Connected", "enabled": false,
                    "children": [{"id": "menu-details", "label": "Details", "enabled": true,
                        "children": []}]}]
            }
        }];
        snapshot.system.osd.data.current = {"schemaVersion": 2, "outputId": "DP-1",
            "kind": "volume", "level": 0.42, "muted": false, "label": "Speakers"};
        return snapshot;
    }

    function loadProductionModel() {
        let qml = source("../../src/services/DesktopModel.qml");
        qml = qml.replace("pragma Singleton", "");
        qml = qml.replace("import QtQuick 6.0",
            "import QtQuick 6.0\nimport \"../../src/services\" as Services");
        qml = qml.replace(/DesktopModelProjection/g, "Services.DesktopModelProjection");
        qml = qml.replace(/DesktopClient/g, "client");
        qml = qml.replace("id: root", `id: root
            property QtObject client: QtObject {
                property string connectionState: "offline"
                property string diagnostic: ""
                property int generation: 0
                property var snapshot: ({})
                property bool snapshotReceived: false
                signal eventAccepted
                signal daemonGenerationChanged
            }`);
        const model = Qt.createQmlObject(qml, testCase, "Task7bProductionDesktopModel");
        verify(model !== null);
        return model;
    }

    function strictAcceptedSnapshot(snapshot, generation) {
        const component = Qt.createComponent("../../src/services/DesktopProtocol.qml");
        verify(component.status === Component.Ready, component.errorString());
        const protocol = createTemporaryObject(component, testCase);
        verify(protocol !== null);
        verify(protocol.acceptEnvelope({
            "schemaVersion": 3,
            "generation": generation,
            "eventId": "33333333-3333-4333-8333-333333333333",
            "emittedAt": "2026-08-31T12:00:00Z",
            "cause": {"kind": "lifecycle"},
            "payload": {"type": "fullSnapshot", "data": snapshot}
        }), protocol.diagnostic);
        return protocol.snapshot;
    }

    function accept(model, snapshot, generation) {
        model.client.snapshot = strictAcceptedSnapshot(snapshot, generation);
        model.client.generation = generation;
        model.client.snapshotReceived = true;
        model.client.connectionState = "ready";
        model.client.eventAccepted();
        wait(0);
    }

    function createView(model, commandSink, reducedMotion) {
        const component = Qt.createComponent("../../src/core/CoreDesktopView.qml");
        verify(component.status === Component.Ready, component.errorString());
        const view = createTemporaryObject(component, testCase, {
            "desktopModel": model,
            "commandClient": commandSink,
            "reducedMotion": Boolean(reducedMotion),
            "width": 700,
            "height": 500
        });
        verify(view !== null, component.errorString());
        wait(0);
        return view;
    }

    function outputById(view, outputId) {
        for (let index = 0; index < view.outputCount; index++) {
            const output = view.outputAt(index);
            if (output && output.outputId === outputId)
                return output;
        }
        return null;
    }

    function test_production_view_instantiates_two_daemon_outputs() {
        const model = loadProductionModel();
        accept(model, fixtureSnapshot(), 1);
        const commands = createTemporaryObject(commandSinkFactory, testCase);
        const view = createView(model, commands, false);

        compare(view.outputCount, 2);
        verify(outputById(view, "DP-1") !== null);
        verify(outputById(view, "HDMI-A-1") !== null);
        compare(outputById(view, "DP-1").outputName, "DP-1");
        compare(findChild(outputById(view, "DP-1"), "task10Background").outputScale, 1);
        compare(findChild(outputById(view, "HDMI-A-1"), "task10Background").outputScale, 2);
    }

    function test_workspaces_are_per_monitor_and_focus_uses_exact_builder() {
        const model = loadProductionModel();
        accept(model, fixtureSnapshot(), 1);
        const commands = createTemporaryObject(commandSinkFactory, testCase);
        const view = createView(model, commands, false);
        const first = outputById(view, "DP-1");
        const second = outputById(view, "HDMI-A-1");

        compare(JSON.stringify(first.workspaceIds), JSON.stringify(["1", "special-music"]));
        compare(first.focusedWorkspaceId, "1");
        compare(JSON.stringify(first.occupiedWorkspaceIds), JSON.stringify(["1"]));
        compare(JSON.stringify(first.specialWorkspaceIds), JSON.stringify(["special-music"]));
        compare(JSON.stringify(second.workspaceIds), JSON.stringify(["2", "3"]));
        compare(JSON.stringify(second.occupiedWorkspaceIds), JSON.stringify(["2"]));

        const workspaceButton = findChild(first, "workspace:special-music");
        verify(workspaceButton !== null);
        verify(workspaceButton.activeFocusOnTab);
        workspaceButton.clicked();
        compare(commands.sent.length, 1);
        compare(JSON.stringify(commands.sent[0]), JSON.stringify({
            "family": "compositor",
            "command": {"type": "focusWorkspace", "data": {"workspaceId": "special-music"}}
        }));
        compare(first.focusedWorkspaceId, "1");
    }

    function test_hotplug_and_fullscreen_suppression_are_independent() {
        const model = loadProductionModel();
        const initial = fixtureSnapshot();
        accept(model, initial, 1);
        const commands = createTemporaryObject(commandSinkFactory, testCase);
        const view = createView(model, commands, false);

        verify(outputById(view, "DP-1").barVisible);
        const fullscreenOutput = outputById(view, "HDMI-A-1");
        verify(!fullscreenOutput.barVisible);
        const hiddenWorkspace = findChild(fullscreenOutput, "workspace:3");
        const hiddenTray = findChild(fullscreenOutput, "trayMenuButton:tray-network");
        verify(hiddenWorkspace !== null && hiddenTray !== null);
        verify(!hiddenWorkspace.enabled);
        verify(!hiddenWorkspace.activeFocusOnTab);
        verify(hiddenWorkspace.Accessible.ignored);
        verify(!hiddenTray.enabled);
        verify(!hiddenTray.activeFocusOnTab);
        verify(hiddenTray.Accessible.ignored);
        hiddenWorkspace.clicked();
        hiddenWorkspace.Accessible.pressAction();
        hiddenTray.clicked();
        hiddenTray.Accessible.pressAction();
        compare(commands.sent.length, 0);
        compare(fullscreenOutput.trayExpandedItemId, "");
        compare(fullscreenOutput.trayPopupOpen, false);

        const replacement = JSON.parse(JSON.stringify(initial));
        replacement.compositor.hyprland.data.windows[1].fullscreen = false;
        replacement.compositor.hyprland.data.monitors =
            replacement.compositor.hyprland.data.monitors.filter(item => item.id !== "DP-1");
        replacement.compositor.hyprland.data.workspaces =
            replacement.compositor.hyprland.data.workspaces.filter(item => item.monitorId !== "DP-1");
        replacement.compositor.hyprland.data.windows =
            replacement.compositor.hyprland.data.windows.filter(item => item.workspaceId !== "1");
        replacement.compositor.hyprland.data.monitors[0].focused = true;
        replacement.compositor.hyprland.data.workspaces[0].focused = true;
        accept(model, replacement, 2);

        compare(view.outputCount, 1);
        compare(view.outputAt(0).outputId, "HDMI-A-1");
        verify(view.outputAt(0).barVisible);
        const restoredWorkspace = findChild(view.outputAt(0), "workspace:3");
        const restoredTray = findChild(view.outputAt(0), "trayMenuButton:tray-network");
        verify(restoredWorkspace.enabled && restoredWorkspace.activeFocusOnTab);
        verify(!restoredWorkspace.Accessible.ignored);
        restoredWorkspace.Accessible.pressAction();
        compare(commands.sent.length, 1);
        compare(commands.sent[0].command.type, "focusWorkspace");
        restoredTray.Accessible.pressAction();
        compare(view.outputAt(0).trayExpandedItemId, "tray-network");

        const readded = JSON.parse(JSON.stringify(initial));
        readded.compositor.hyprland.data.windows[1].fullscreen = false;
        accept(model, readded, 3);
        compare(view.outputCount, 2);
        const readdedOutput = outputById(view, "DP-1");
        verify(readdedOutput !== null);
        compare(findChild(readdedOutput, "task10Background").outputScale, 1);
    }

    function test_tray_preserves_stable_ids_and_routes_only_supported_menu_actions() {
        const model = loadProductionModel();
        accept(model, fixtureSnapshot(), 1);
        const commands = createTemporaryObject(commandSinkFactory, testCase);
        const output = outputById(createView(model, commands, false), "DP-1");

        compare(output.trayItems.length, 1);
        compare(output.trayItems[0].id, "tray-network");
        compare(output.trayItems[0].menu.children[0].id, "menu-status");
        compare(output.trayItems[0].menu.children[0].children[0].id, "menu-details");
        verify(!output.trayActivationSupported);
        verify(output.menuActivationSupported);
        verify(!output.activateTrayItem("tray-network"));
        verify(!output.activateMenuNode("tray-network", "menu-status"));
        const trayButton = findChild(output, "trayMenuButton:tray-network");
        verify(trayButton !== null);
        verify(trayButton.activeFocusOnTab);
        trayButton.clicked();
        wait(0);
        const menuButton = findChild(output, "trayMenuNode:menu-details");
        const disabledMenuButton = findChild(output, "trayMenuNode:menu-status");
        verify(menuButton !== null);
        verify(disabledMenuButton !== null);
        verify(!disabledMenuButton.enabled);
        disabledMenuButton.Accessible.pressAction();
        compare(commands.sent.length, 0);
        verify(menuButton.enabled, "menu enabled state: bar=" + output.barVisible
            + " expanded=" + output.trayExpandedItemId
            + " node=" + menuButton.node.enabled
            + " item=" + menuButton.trayItemId
            + " supported=" + output.menuActivationSupported
            + " parentEnabled=" + menuButton.parent.enabled);
        verify(menuButton.activeFocusOnTab);
        menuButton.Accessible.pressAction();
        compare(JSON.stringify(commands.sent), JSON.stringify([{
            "family": "utility",
            "command": {"type": "invokeTrayMenu", "data": {
                "itemId": "tray-network", "menuId": "menu-details"}}
        }]));
    }

    function test_tray_expansion_clears_on_fullscreen_and_removed_item() {
        const model = loadProductionModel();
        const initial = fixtureSnapshot();
        accept(model, initial, 1);
        const commands = createTemporaryObject(commandSinkFactory, testCase);
        const view = createView(model, commands, false);
        const output = outputById(view, "DP-1");
        findChild(output, "trayMenuButton:tray-network").clicked();
        compare(output.trayExpandedItemId, "tray-network");
        verify(output.trayPopupOpen);
        const retainedMenuButton = findChild(output, "trayMenuNode:menu-details");
        verify(retainedMenuButton !== null && retainedMenuButton.enabled,
            "retained menu enabled state: bar=" + output.barVisible
            + " expanded=" + output.trayExpandedItemId);

        const fullscreen = JSON.parse(JSON.stringify(initial));
        fullscreen.compositor.hyprland.data.windows[0].fullscreen = true;
        accept(model, fullscreen, 2);
        compare(output.trayExpandedItemId, "");
        verify(!output.trayPopupOpen);
        verify(findChild(output, "trayMenuNode:menu-details") === null);
        verify(!output.activateMenuNode("tray-network", "menu-details"));
        compare(commands.sent.length, 0);

        const restored = JSON.parse(JSON.stringify(initial));
        accept(model, restored, 3);
        findChild(output, "trayMenuButton:tray-network").clicked();
        compare(output.trayExpandedItemId, "tray-network");
        const withoutTray = JSON.parse(JSON.stringify(restored));
        withoutTray.utilities.trayItems.data = [];
        accept(model, withoutTray, 4);
        compare(output.trayExpandedItemId, "");
        verify(!output.trayPopupOpen);
    }

    function test_osd_routes_exact_supported_commands_without_optimistic_state() {
        const model = loadProductionModel();
        const initial = fixtureSnapshot();
        accept(model, initial, 1);
        const commands = createTemporaryObject(commandSinkFactory, testCase);
        const view = createView(model, commands, false);
        const first = outputById(view, "DP-1");
        const second = outputById(view, "HDMI-A-1");

        verify(first.osdVisible);
        compare(first.osdKind, "volume");
        compare(first.osdLevel, 0.42);
        verify(!second.osdVisible);
        verify(first.volumeControlAvailable);
        verify(first.muteControlAvailable);
        verify(!first.microphoneControlAvailable);
        verify(first.brightnessControlAvailable);

        const levelSlider = findChild(first, "osdLevelSlider");
        const muteButton = findChild(first, "osdMuteButton");
        verify(levelSlider !== null && levelSlider.enabled);
        verify(muteButton !== null && muteButton.enabled);
        verify(levelSlider.activeFocusOnTab && muteButton.activeFocusOnTab);
        levelSlider.value = 0.8;
        levelSlider.moved();
        muteButton.Accessible.pressAction();
        compare(first.osdLevel, 0.42);
        compare(levelSlider.value, 0.42);
        verify(!first.osdMuted);
        compare(JSON.stringify(commands.sent), JSON.stringify([
            {"family": "system", "command": {"domain": "audio", "action": {
                "type": "setNodeVolume", "data": {"nodeId": "speaker", "level": 0.8}}}},
            {"family": "system", "command": {"domain": "audio", "action": {
                "type": "setNodeMuted", "data": {"nodeId": "speaker", "muted": true}}}}
        ]));

        const microphone = JSON.parse(JSON.stringify(initial));
        microphone.system.audio.data.nodes.push({"id": "microphone", "name": "Microphone",
            "kind": "input", "volume": 0.35, "muted": true, "isDefault": true});
        microphone.system.osd.data.current = {"schemaVersion": 2, "outputId": "DP-1",
            "kind": "microphone", "level": 0.35, "muted": true, "label": "Microphone"};
        accept(model, microphone, 2);
        verify(first.microphoneControlAvailable);
        compare(first.osdKind, "microphone");
        levelSlider.value = 0.45;
        levelSlider.moved();
        muteButton.Accessible.pressAction();
        compare(JSON.stringify(commands.sent[2]), JSON.stringify(
            {"family": "system", "command": {"domain": "audio", "action": {
                "type": "setNodeVolume", "data": {"nodeId": "microphone", "level": 0.45}}}}));
        compare(JSON.stringify(commands.sent[3]), JSON.stringify(
            {"family": "system", "command": {"domain": "audio", "action": {
                "type": "setNodeMuted", "data": {"nodeId": "microphone", "muted": false}}}}));

        const confirmed = JSON.parse(JSON.stringify(microphone));
        confirmed.system.osd.data.current = {"schemaVersion": 2, "outputId": "DP-1",
            "kind": "brightness", "level": 0.65, "label": "Display"};
        accept(model, confirmed, 3);
        compare(first.osdKind, "brightness");
        compare(first.osdLevel, 0.65);
        levelSlider.value = 0.75;
        levelSlider.moved();
        compare(first.osdLevel, 0.65);
        compare(levelSlider.value, 0.65);
        compare(JSON.stringify(commands.sent[4]), JSON.stringify(
            {"family": "system", "command": {"domain": "display", "action": {
                "type": "setBrightness", "data": {"outputId": "DP-1", "level": 0.75}}}}));

        const degraded = JSON.parse(JSON.stringify(confirmed));
        degraded.system.osd.data.current.level = 0.75;
        degraded.system.audio = {"status": "unsupported",
            "diagnostic": {"message": "Audio unavailable"}};
        accept(model, degraded, 4);
        compare(first.osdLevel, 0.75);
        verify(!first.volumeControlAvailable);
        verify(!first.muteControlAvailable);
        verify(!first.microphoneControlAvailable);
        verify(first.brightnessControlAvailable);

        const power = JSON.parse(JSON.stringify(degraded));
        power.system.osd.data.current = {"schemaVersion": 2, "outputId": "DP-1",
            "kind": "powerProfile", "label": "Balanced"};
        accept(model, power, 5);
        compare(first.osdKind, "powerProfile");
        verify(!levelSlider.visible);
        verify(!levelSlider.enabled && levelSlider.Accessible.ignored);
        verify(!muteButton.visible);
        const statusText = findChild(first, "osdStatusText");
        verify(statusText !== null);
        compare(statusText.text, "Balanced");
    }

    function test_recording_lifecycle_and_area_selection_follow_confirmed_v3_state() {
        const model = loadProductionModel();
        const initial = fixtureSnapshot();
        accept(model, initial, 1);
        const commands = createTemporaryObject(commandSinkFactory, testCase);
        const output = outputById(createView(model, commands, false), "DP-1");
        verify(output.openOverlay("nexus"));
        verify(output.setNexusTab("utilities"));
        const utilities = findChild(output, "task10Utilities");
        const screenshot = findChild(output, "utilityScreenshot");
        const recording = findChild(output, "utilityRecording");
        verify(utilities !== null && screenshot !== null && recording !== null);
        compare(screenshot.Accessible.name, "Screenshot / area");

        verify(utilities.requestScreenshot());
        verify(utilities.requestRecording());
        compare(output.recordingState.status, "inactive");
        compare(commands.sent[0].command.type, "screenshot");
        compare(commands.sent[0].command.data.outputId, "DP-1");
        compare(commands.sent[1].command.type, "startRecording");

        const active = JSON.parse(JSON.stringify(initial));
        active.utilities.recording.data = {"status": "recording",
            "recordingId": "recording-1", "outputId": "DP-1"};
        accept(model, active, 2);
        compare(recording.Accessible.name, "Pause recording");
        verify(utilities.requestRecording());
        compare(output.recordingState.status, "recording");
        compare(commands.sent[2].command.type, "pauseRecording");

        const paused = JSON.parse(JSON.stringify(active));
        paused.utilities.recording.data.status = "paused";
        accept(model, paused, 3);
        compare(recording.Accessible.name, "Stop recording");
        verify(utilities.requestRecording());
        compare(output.recordingState.status, "paused");
        compare(commands.sent[3].command.type, "stopRecording");

        const stopped = JSON.parse(JSON.stringify(initial));
        accept(model, stopped, 4);
        compare(output.recordingState.status, "inactive");
        compare(recording.Accessible.name, "Record");
    }

    function test_vertical_layout_clipping_placement_and_motion_tokens() {
        const model = loadProductionModel();
        accept(model, fixtureSnapshot(), 1);
        const commands = createTemporaryObject(commandSinkFactory, testCase);
        const animated = outputById(createView(model, commands, false), "DP-1");
        const reduced = outputById(createView(model, commands, true), "DP-1");

        compare(animated.barEdge, "left");
        verify(animated.barClips);
        compare(animated.osdPlacement, "bottom-center");
        verify(animated.osdClips);
        compare(animated.motionDuration, 180);
        compare(reduced.motionDuration, 0);
    }

    function test_bar_status_affordances_are_daemon_backed_and_independently_degraded() {
        const model = loadProductionModel();
        const initial = fixtureSnapshot();
        accept(model, initial, 1);
        const output = outputById(createView(model,
            createTemporaryObject(commandSinkFactory, testCase), false), "DP-1");

        verify(output.networkStatusAvailable);
        verify(output.bluetoothStatusAvailable);
        verify(output.audioStatusAvailable);
        verify(output.batteryStatusAvailable);
        verify(!output.clockStatusAvailable);
        compare(output.clockStatusText, "--:--");
        compare(output.batteryStatusText, "72%");
        for (const name of ["network", "bluetooth", "audio", "battery", "clock"]) {
            const indicator = findChild(output, "barStatus:" + name);
            verify(indicator !== null, name);
            verify(indicator.Accessible.name.length > 0, name);
        }

        const degraded = JSON.parse(JSON.stringify(initial));
        degraded.system.bluetooth = {"status": "unsupported",
            "diagnostic": {"message": "Bluetooth unavailable"}};
        accept(model, degraded, 2);
        verify(output.networkStatusAvailable);
        verify(!output.bluetoothStatusAvailable);
        verify(output.audioStatusAvailable);
        verify(output.batteryStatusAvailable);
        compare(output.bluetoothStatusText, "Bluetooth unavailable");
    }

    function test_surface_focus_changes_only_after_strict_confirmed_snapshot() {
        const model = loadProductionModel();
        const initial = fixtureSnapshot();
        accept(model, initial, 1);
        const commands = createTemporaryObject(commandSinkFactory, testCase);
        const view = createView(model, commands, false);
        const first = outputById(view, "DP-1");
        const second = outputById(view, "HDMI-A-1");
        const firstIdentity = first;
        const secondIdentity = second;
        const firstButton = findChild(first, "workspace:1");
        const secondButton = findChild(second, "workspace:2");

        compare(first.focusedWorkspaceId, "1");
        compare(second.focusedWorkspaceId, "");
        verify(firstButton.focused);
        verify(!secondButton.focused);
        secondButton.clicked();
        compare(first.focusedWorkspaceId, "1");
        compare(second.focusedWorkspaceId, "");

        const confirmed = JSON.parse(JSON.stringify(initial));
        confirmed.compositor.hyprland.data.monitors[0].focused = false;
        confirmed.compositor.hyprland.data.monitors[1].focused = true;
        confirmed.compositor.hyprland.data.workspaces.forEach(workspace => {
            workspace.focused = workspace.id === "2";
        });
        accept(model, confirmed, 2);

        verify(outputById(view, "DP-1") === firstIdentity);
        verify(outputById(view, "HDMI-A-1") === secondIdentity);
        compare(first.focusedWorkspaceId, "");
        compare(second.focusedWorkspaceId, "2");
        verify(!firstButton.focused);
        verify(secondButton.focused);
    }

    function test_shell_host_instantiates_offscreen_with_two_confirmed_outputs() {
        const model = loadProductionModel();
        accept(model, fixtureSnapshot(), 1);
        const commands = createTemporaryObject(commandSinkFactory, testCase);
        const component = Qt.createComponent("../../src/core/CoreDesktopHost.qml");
        verify(component.status === Component.Ready, component.errorString());
        const host = createTemporaryObject(component, testCase, {
            "desktopModel": model,
            "commandClient": commands,
            "tokens": ({"motionDuration": 180})
        });
        verify(host !== null, component.errorString());
        compare(host.outputCount, 2);
    }

    function test_task10_views_are_reachable_and_route_strict_v3_without_optimism() {
        const model = loadProductionModel();
        accept(model, fixtureSnapshot(), 1);
        const commands = createTemporaryObject(commandSinkFactory, testCase);
        const output = outputById(createView(model, commands, false), "DP-1");

        verify(findChild(output, "task10Background") !== null);
        verify(output.openOverlay("nexus"));
        output.setNexusTab("utilities");
        wait(0);
        const utilities = findChild(output, "task10Utilities");
        verify(utilities !== null);
        verify(utilities.requestIdleInhibited(true));
        verify(utilities.requestRecording());
        verify(utilities.requestScreenshot());
        verify(utilities.requestColorPicker());
        verify(utilities.requestGameMode(true));
        compare(output.idleInhibited, false);
        compare(output.gameMode, false);

        output.setNexusTab("windows");
        wait(0);
        const windows = findChild(output, "task10WindowInfo");
        verify(windows !== null);
        compare(windows.windowRows.length, 1);
        verify(!windows.requestFullscreen("0x1234"));
        verify(windows.requestFocus("0x1234"));

        output.setNexusTab("session");
        wait(0);
        const session = findChild(output, "task10Session");
        const overlay = findChild(output, "coreOverlayView");
        verify(session !== null);
        verify(overlay !== null);
        compare(overlay.initialFocusItem.objectName, "nexusTab:session");
        verify(overlay.initialFocusItem.activeFocus);
        verify(session.requestAction("lock"));
        verify(session.requestAction("powerOff"));
        compare(commands.sent.filter(item => item.family === "session").length, 1);
        verify(session.requestAction("powerOff"));

        compare(JSON.stringify(commands.sent), JSON.stringify([
            {"family":"utility","command":{"type":"setIdleInhibited","data":{"enabled":true}}},
            {"family":"utility","command":{"type":"startRecording","data":{"outputId":"DP-1","audio":false}}},
            {"family":"utility","command":{"type":"screenshot","data":{"outputId":"DP-1"}}},
            {"family":"utility","command":{"type":"pickColor"}},
            {"family":"utility","command":{"type":"setGameMode","data":{"enabled":true}}},
            {"family":"compositor","command":{"type":"focusWindow","data":{"windowId":"0x1234"}}},
            {"family":"session","command":"lock"},
            {"family":"session","command":"powerOff"}
        ]));
    }

}
