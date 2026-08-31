// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0
import QtTest 1.0

TestCase {
    id: testCase
    name: "CoreDesktopOverlays"
    width: 1280
    height: 760

    Component {
        id: commandSinkFactory
        QtObject {
            property bool busy: false
            property var sent: []
            function append(family, command) {
                sent = sent.concat([{family: family, command: command}]);
                return true;
            }
            function system(command) { return append("system", command); }
            function notification(command) { return append("notification", command); }
            function launcher(command) { return append("launcher", command); }
            function appearance(command) { return append("appearance", command); }
            function compositor(command) { return append("compositor", command); }
            function utility(command) { return append("utility", command); }
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
            "../fixtures/task7b-sdk-full-snapshot.json"));
        const snapshot = envelope.payload.data;
        const hyprland = snapshot.compositor.hyprland.data;
        hyprland.monitors.push({id: "HDMI-A-1", name: "HDMI-A-1",
            width: 1920, height: 1080, scale: 1, focused: false});
        hyprland.workspaces.push({id: "2", name: "2", monitorId: "HDMI-A-1", focused: false});
        snapshot.launcher.entries.push({
            id: "org.sleepy.Terminal.desktop", name: "Terminal", icon: "terminal"});
        snapshot.notifications.active[0].actions = [{
            id: "open", label: "Open", state: "available"}];
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
        const model = Qt.createQmlObject(qml, testCase, "Task7cProductionDesktopModel");
        verify(model !== null);
        return model;
    }

    function strictAcceptedSnapshot(snapshot, generation) {
        const component = Qt.createComponent("../../src/services/DesktopProtocol.qml");
        verify(component.status === Component.Ready, component.errorString());
        const protocol = createTemporaryObject(component, testCase);
        verify(protocol !== null);
        verify(protocol.acceptEnvelope({
            schemaVersion: 3,
            generation: generation,
            eventId: "44444444-4444-4444-8444-444444444444",
            emittedAt: "2026-08-31T12:00:00Z",
            cause: {kind: "lifecycle"},
            payload: {type: "fullSnapshot", data: snapshot}
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

    function createView(model, commands) {
        const component = Qt.createComponent("../../src/core/CoreDesktopView.qml");
        verify(component.status === Component.Ready, component.errorString());
        const view = createTemporaryObject(component, testCase, {
            desktopModel: model,
            commandClient: commands,
            width: 1280,
            height: 720
        });
        verify(view !== null, component.errorString());
        wait(0);
        return view;
    }

    function outputById(view, outputId) {
        for (let index = 0; index < view.outputCount; ++index) {
            const output = view.outputAt(index);
            if (output && output.outputId === outputId)
                return output;
        }
        return null;
    }

    function setup() {
        const model = loadProductionModel();
        accept(model, fixtureSnapshot(), 1);
        const commands = createTemporaryObject(commandSinkFactory, testCase);
        return {model: model, commands: commands, view: createView(model, commands)};
    }

    function test_production_per_output_host_enforces_one_open_surface() {
        const fixture = setup();
        const first = outputById(fixture.view, "DP-1");
        const second = outputById(fixture.view, "HDMI-A-1");
        verify(first !== null && second !== null);
        compare(first.activeOverlay, "");
        verify(first.openOverlay("launcher"));
        compare(first.activeOverlay, "launcher");
        verify(first.openOverlay("notifications"));
        compare(first.activeOverlay, "notifications");
        compare(second.activeOverlay, "");
        verify(second.openOverlay("launcher"));
        compare(second.activeOverlay, "launcher");
        compare(first.activeOverlay, "notifications");
        verify(!first.openOverlay("lock"));

        const launcherTrigger = findChild(first, "overlayTrigger:launcher");
        verify(launcherTrigger !== null);
        verify(launcherTrigger.activeFocusOnTab);
        compare(launcherTrigger.Accessible.role, Accessible.Button);
        launcherTrigger.forceActiveFocus();
        tryVerify(function() { return launcherTrigger.activeFocus; });
        launcherTrigger.Accessible.pressAction();
        compare(first.activeOverlay, "launcher");
        const overlay = findChild(first, "coreOverlayView");
        verify(overlay !== null);
        const launcherSearch = findChild(first, "launcherSearch");
        verify(launcherSearch !== null);
        tryVerify(function() { return launcherSearch.activeFocus; });
        keyClick(Qt.Key_Escape);
        compare(first.activeOverlay, "");
        tryVerify(function() { return launcherTrigger.activeFocus; });
    }

    function test_dashboard_is_a_per_output_surface_with_keyboard_focus_return() {
        const fixture = setup();
        const first = outputById(fixture.view, "DP-1");
        const second = outputById(fixture.view, "HDMI-A-1");
        verify(first !== null && second !== null);

        const trigger = findChild(first, "overlayTrigger:dashboard");
        verify(trigger !== null, "production dashboard trigger was not instantiated");
        verify(trigger.activeFocusOnTab);
        compare(trigger.Accessible.role, Accessible.Button);
        const firstWorkspace = findChild(first, "workspace:1");
        verify(firstWorkspace !== null);
        const triggerBottom = trigger.mapToItem(first, 0, trigger.height).y;
        const workspaceTop = firstWorkspace.mapToItem(first, 0, 0).y;
        verify(triggerBottom <= workspaceTop,
            "dashboard trigger overlaps the first workspace control");
        trigger.forceActiveFocus();
        tryVerify(function() { return trigger.activeFocus; });
        trigger.Accessible.pressAction();
        compare(first.activeOverlay, "dashboard");
        compare(second.activeOverlay, "");

        const overviewTab = findChild(first, "dashboardTab:overview");
        verify(overviewTab !== null, "dashboard initial tab was not instantiated");
        tryVerify(function() { return overviewTab.activeFocus; });
        verify(first.openOverlay("launcher"));
        compare(first.activeOverlay, "launcher");
        verify(second.openOverlay("dashboard"));
        compare(second.activeOverlay, "dashboard");
        compare(first.activeOverlay, "launcher");

        first.openOverlay("dashboard", trigger);
        compare(first.dashboardTab, "overview");
        verify(first.setDashboardTab("weather"));
        compare(first.dashboardTab, "weather");
        verify(!first.setDashboardTab("nexus"));
        keyClick(Qt.Key_Escape);
        compare(first.activeOverlay, "");
        compare(first.dashboardTab, "overview");
        tryVerify(function() { return trigger.activeFocus; });
    }

    function test_dashboard_projects_confirmed_v3_rows_and_routes_media_without_optimism() {
        const fixture = setup();
        const output = outputById(fixture.view, "DP-1");
        verify(output.openOverlay("dashboard"));

        verify(output.mediaAvailable);
        verify(output.calendarAvailable);
        verify(output.weatherAvailable);
        verify(output.resourcesAvailable);
        compare(output.players.length, 1);
        compare(output.players[0].id, "firefox.instance1");
        compare(output.calendarEvents.length, 1);
        compare(output.calendarEvents[0].id, "meeting@example");
        compare(output.weatherForecast.length, 1);
        compare(output.weatherForecast[0].at, "2026-08-30T12:00:00Z");
        compare(output.resourceSamples.length, 1);
        compare(output.resourceSamples[0].id, "host");

        const playPause = findChild(output,
            "dashboardMediaTransport:firefox.instance1:playPause");
        verify(playPause !== null, "confirmed player transport was not instantiated");
        verify(playPause.enabled && playPause.activeFocusOnTab);
        compare(playPause.Accessible.role, Accessible.Button);

        verify(!output.controlPlayer("missing-player", "playPause"));
        verify(!output.controlPlayer("firefox.instance1", "stop"));
        compare(fixture.commands.sent.length, 0);
        verify(output.controlPlayer("firefox.instance1", "playPause"));
        compare(JSON.stringify(fixture.commands.sent), JSON.stringify([{
            family: "system",
            command: {domain: "media", action: {type: "transport", data: {
                playerId: "firefox.instance1", transport: "playPause"}}}
        }]));
        verify(output.players[0].playing,
            "dashboard optimistically changed daemon-owned player state");
        compare(output.activeOverlay, "dashboard");

        fixture.commands.busy = true;
        wait(0);
        verify(!playPause.enabled && !playPause.activeFocusOnTab);
        compare(playPause.Accessible.description,
            "Another desktop command is pending");
        verify(!output.controlPlayer("firefox.instance1", "next"));
        compare(fixture.commands.sent.length, 1);
    }

    function test_dashboard_producer_failures_are_independent() {
        const model = loadProductionModel();
        const degraded = fixtureSnapshot();
        degraded.system.media = {status: "unsupported",
            diagnostic: {message: "Media unavailable"}};
        degraded.weather.availability = {status: "timeout",
            diagnostic: {message: "Weather timeout"}};
        accept(model, degraded, 1);
        const commands = createTemporaryObject(commandSinkFactory, testCase);
        const output = outputById(createView(model, commands), "DP-1");
        verify(output.openOverlay("dashboard"));

        verify(!output.mediaAvailable);
        compare(output.mediaDiagnostic, "Media unavailable");
        compare(output.players.length, 0);
        verify(output.calendarAvailable);
        compare(output.calendarEvents.length, 1);
        verify(!output.weatherAvailable);
        compare(output.weatherDiagnostic, "Weather timeout");
        compare(output.weatherForecast.length, 0);
        verify(output.resourcesAvailable);
        compare(output.resourceSamples.length, 1);
        verify(findChild(output, "dashboardUnavailable:media") !== null);
        verify(findChild(output, "dashboardUnavailable:weather") !== null);
        verify(findChild(output, "dashboardCalendarEvent:meeting@example") !== null);
        verify(findChild(output, "dashboardResource:host") !== null);
        output.setDashboardTab("media");
        compare(output.dashboardTab, "media");
        output.setDashboardTab("schedule");
        compare(output.dashboardTab, "schedule");
        output.setDashboardTab("weather");
        compare(output.dashboardTab, "weather");
        output.setDashboardTab("resources");
        compare(output.dashboardTab, "resources");
        verify(!output.controlPlayer("firefox.instance1", "playPause"));
        compare(commands.sent.length, 0);
    }

    function test_dashboard_renders_daemon_markup_as_literal_plain_text() {
        const model = loadProductionModel();
        const hostile = fixtureSnapshot();
        hostile.system.media.data.players[0].title = "<b>Quiet & Bold</b>";
        hostile.calendar.snapshot.events[0].summary = "<img src=x> Calendar";
        hostile.weather.availability = {status: "timeout", diagnostic: {
            message: "<i>Weather timeout</i>"}};
        accept(model, hostile, 1);
        const commands = createTemporaryObject(commandSinkFactory, testCase);
        const output = outputById(createView(model, commands), "DP-1");
        verify(output.openOverlay("dashboard"));

        verify(output.setDashboardTab("media"));
        const playerTitle = findChild(output,
            "dashboardPlayerTitle:firefox.instance1");
        verify(playerTitle !== null, "dashboard player title Text was not exposed");
        compare(playerTitle.text, "<b>Quiet & Bold</b>");
        compare(playerTitle.textFormat, Text.PlainText);

        verify(output.setDashboardTab("schedule"));
        const calendarSummary = findChild(output,
            "dashboardCalendarSummary:meeting@example");
        verify(calendarSummary !== null,
            "dashboard calendar summary Text was not exposed");
        compare(calendarSummary.text, "<img src=x> Calendar");
        compare(calendarSummary.textFormat, Text.PlainText);

        verify(output.setDashboardTab("weather"));
        const diagnostic = findChild(output, "dashboardUnavailable:weather");
        verify(diagnostic !== null);
        compare(diagnostic.text, "<i>Weather timeout</i>");
        compare(diagnostic.textFormat, Text.PlainText);
    }

    function test_nexus_is_a_per_output_surface_with_local_tabs_and_focus_return() {
        const fixture = setup();
        const first = outputById(fixture.view, "DP-1");
        const second = outputById(fixture.view, "HDMI-A-1");
        const trigger = findChild(first, "overlayTrigger:nexus");
        verify(trigger !== null, "production Nexus trigger was not instantiated");
        const firstWorkspace = findChild(first, "workspace:1");
        verify(firstWorkspace !== null);
        verify(trigger.mapToItem(first, 0, trigger.height).y
                <= firstWorkspace.mapToItem(first, 0, 0).y,
            "Nexus trigger overlaps the first workspace control");
        trigger.forceActiveFocus();
        trigger.Accessible.pressAction();
        compare(first.activeOverlay, "nexus");
        compare(second.activeOverlay, "");
        compare(first.nexusTab, "network");
        const networkTab = findChild(first, "nexusTab:network");
        verify(networkTab !== null);
        tryVerify(function() { return networkTab.activeFocus; });
        verify(first.setNexusTab("bluetooth"));
        compare(first.nexusTab, "bluetooth");
        verify(first.setNexusTab("audio"));
        verify(first.setNexusTab("appearance"));
        verify(!first.setNexusTab("lock"));
        keyClick(Qt.Key_Escape);
        compare(first.activeOverlay, "");
        compare(first.nexusTab, "network");
        tryVerify(function() { return trigger.activeFocus; });
    }

    function test_nexus_routes_exact_confirmed_system_and_appearance_commands_without_optimism() {
        const model = loadProductionModel();
        const snapshot = fixtureSnapshot();
        snapshot.system.bluetooth.data.devices.push({id: "keyboard", name: "Keyboard",
            paired: false, connected: false});
        snapshot.system.bluetooth.data.devices.push({id: "mouse", name: "Mouse",
            paired: true, connected: false});
        accept(model, snapshot, 1);
        const commands = createTemporaryObject(commandSinkFactory, testCase);
        const output = outputById(createView(model, commands), "DP-1");
        verify(output.openOverlay("nexus"));

        verify(output.networkAvailable && output.bluetoothAvailable
            && output.audioAvailable && output.appearanceAvailable);
        compare(output.accessPoints.length, 1);
        compare(output.bluetoothDevices.length, 3);
        compare(output.audioNodes.length, 1);
        compare(output.currentThemeId, "018f3f4c-8af1-7f6b-bf42-1bd472868e67");
        compare(output.currentWallpaperId, "moon-cache-handle");
        verify(!output.connectWifi("missing"));
        verify(!output.disconnectBluetoothDevice("missing"));
        verify(!output.setNodeVolume("missing", 0.5));
        verify(!output.applyTheme("invented-theme"));
        verify(!output.applyWallpaper("invented-wallpaper"));

        verify(output.setWifiEnabled(false));
        verify(output.scanWifi());
        verify(output.connectWifi("ap-home"));
        verify(output.disconnectNetwork("wifi-home"));
        verify(output.setBluetoothPowered(false));
        verify(output.scanBluetooth());
        verify(output.pairBluetoothDevice("keyboard"));
        verify(output.connectBluetoothDevice("mouse"));
        verify(output.disconnectBluetoothDevice("headphones"));
        verify(output.setDefaultAudioNode("speaker"));
        verify(output.setNodeVolume("speaker", 0.5));
        verify(output.setNodeMuted("speaker", true));
        verify(output.setStreamVolume("stream-firefox", 0.4));
        verify(output.setStreamMuted("stream-firefox", true));
        verify(output.applyTheme(output.currentThemeId));
        verify(output.applyWallpaper(output.currentWallpaperId));
        verify(output.setReducedMotion(false));
        verify(output.setOpaque(false));

        compare(JSON.stringify(commands.sent), JSON.stringify([
            {family: "system", command: {domain: "network", action: {
                type: "setWifiEnabled", data: {enabled: false}}}},
            {family: "system", command: {domain: "network", action: {type: "scanWifi"}}},
            {family: "system", command: {domain: "network", action: {
                type: "connectWifi", data: {accessPointId: "ap-home"}}}},
            {family: "system", command: {domain: "network", action: {
                type: "disconnect", data: {connectionId: "wifi-home"}}}},
            {family: "system", command: {domain: "bluetooth", action: {
                type: "setPowered", data: {powered: false}}}},
            {family: "system", command: {domain: "bluetooth", action: {type: "scan"}}},
            {family: "system", command: {domain: "bluetooth", action: {
                type: "pair", data: {deviceId: "keyboard"}}}},
            {family: "system", command: {domain: "bluetooth", action: {
                type: "connect", data: {deviceId: "mouse"}}}},
            {family: "system", command: {domain: "bluetooth", action: {
                type: "disconnect", data: {deviceId: "headphones"}}}},
            {family: "system", command: {domain: "audio", action: {
                type: "setDefaultNode", data: {nodeId: "speaker"}}}},
            {family: "system", command: {domain: "audio", action: {
                type: "setNodeVolume", data: {nodeId: "speaker", level: 0.5}}}},
            {family: "system", command: {domain: "audio", action: {
                type: "setNodeMuted", data: {nodeId: "speaker", muted: true}}}},
            {family: "system", command: {domain: "audio", action: {
                type: "setStreamVolume", data: {streamId: "stream-firefox", level: 0.4}}}},
            {family: "system", command: {domain: "audio", action: {
                type: "setStreamMuted", data: {streamId: "stream-firefox", muted: true}}}},
            {family: "appearance", command: {type: "applyTheme", data: {
                themeId: "018f3f4c-8af1-7f6b-bf42-1bd472868e67"}}},
            {family: "appearance", command: {type: "setWallpaper", data: {
                wallpaperId: "moon-cache-handle"}}},
            {family: "appearance", command: {type: "setReducedMotion", data: {
                enabled: false}}},
            {family: "appearance", command: {type: "setOpaque", data: {
                enabled: false}}}
        ]));
        verify(output.networkData.wifiEnabled,
            "Nexus optimistically changed confirmed Wi-Fi state");
        verify(output.bluetoothDevices[0].connected,
            "Nexus optimistically changed confirmed Bluetooth state");
        compare(output.audioNodes[0].volume, 0.42);
        verify(output.reducedMotion);
        verify(output.opaque);

        commands.busy = true;
        wait(0);
        verify(!output.scanWifi());
        verify(!output.setNodeMuted("speaker", false));
        verify(!output.setReducedMotion(true));
        compare(commands.sent.length, 18);
    }

    function test_nexus_radio_guards_and_audio_accessibility_match_action_contracts() {
        const model = loadProductionModel();
        const snapshot = fixtureSnapshot();
        snapshot.system.network.data.wifiEnabled = false;
        snapshot.system.bluetooth.data.powered = false;
        accept(model, snapshot, 1);
        const commands = createTemporaryObject(commandSinkFactory, testCase);
        const output = outputById(createView(model, commands), "DP-1");
        verify(output.openOverlay("nexus"));

        const wifiConnect = findChild(output, "nexusWifiConnect:ap-home");
        const wifiScan = findChild(output, "nexusWifiScan");
        verify(wifiConnect !== null && wifiScan !== null);
        verify(!wifiConnect.enabled && !wifiConnect.activeFocusOnTab);
        compare(wifiScan.Accessible.description, "Wi-Fi is off");
        verify(!output.connectWifi("ap-home"));
        output.setNexusTab("bluetooth");
        const bluetoothAction = findChild(output, "nexusBluetoothAction:headphones");
        const bluetoothScan = findChild(output, "nexusBluetoothScan");
        verify(bluetoothAction !== null && bluetoothScan !== null);
        verify(!bluetoothAction.enabled && !bluetoothAction.activeFocusOnTab);
        compare(bluetoothScan.Accessible.description, "Bluetooth is off");
        verify(!output.disconnectBluetoothDevice("headphones"));

        output.setNexusTab("audio");
        const nodeDown = findChild(output, "nexusNodeVolumeDown:speaker");
        const nodeUp = findChild(output, "nexusNodeVolumeUp:speaker");
        const nodeMute = findChild(output, "nexusNodeMute:speaker");
        const streamDown = findChild(output, "nexusStreamVolumeDown:stream-firefox");
        verify(nodeDown !== null && nodeUp !== null && nodeMute !== null
            && streamDown !== null);
        compare(nodeDown.Accessible.name, "Decrease Speakers volume");
        compare(nodeUp.Accessible.name, "Increase Speakers volume");
        compare(nodeMute.Accessible.name, "Mute Speakers");
        compare(streamDown.Accessible.name, "Decrease Firefox volume");
        compare(commands.sent.length, 0);
        commands.busy = true;
        wait(0);
        verify(!nodeMute.enabled && !nodeMute.activeFocusOnTab);
        compare(nodeMute.Accessible.description,
            "Another desktop command is pending");
    }

    function test_nexus_capabilities_degrade_independently_and_render_ids_as_plain_text() {
        const model = loadProductionModel();
        const degraded = fixtureSnapshot();
        degraded.system.network = {status: "timeout", diagnostic: {
            message: "<b>Network timeout</b>"}};
        degraded.appearance.availability = {status: "unsupported", diagnostic: {
            message: "<img src=x> Appearance unavailable"}};
        accept(model, degraded, 1);
        const commands = createTemporaryObject(commandSinkFactory, testCase);
        const output = outputById(createView(model, commands), "DP-1");
        verify(output.openOverlay("nexus"));

        verify(!output.networkAvailable);
        verify(output.bluetoothAvailable && output.audioAvailable);
        verify(!output.appearanceAvailable);
        compare(output.accessPoints.length, 0);
        verify(!output.scanWifi());
        verify(output.scanBluetooth());
        compare(commands.sent.length, 1);
        const networkDiagnostic = findChild(output, "nexusUnavailable:network");
        verify(networkDiagnostic !== null);
        compare(networkDiagnostic.text, "<b>Network timeout</b>");
        compare(networkDiagnostic.textFormat, Text.PlainText);
        verify(output.setNexusTab("appearance"));
        const appearanceDiagnostic = findChild(output, "nexusUnavailable:appearance");
        verify(appearanceDiagnostic !== null);
        compare(appearanceDiagnostic.textFormat, Text.PlainText);
        verify(!output.applyTheme("018f3f4c-8af1-7f6b-bf42-1bd472868e67"));
    }

    function test_launcher_filters_confirmed_entries_and_routes_only_desktop_launch() {
        const fixture = setup();
        const output = outputById(fixture.view, "DP-1");
        output.openOverlay("launcher");
        output.launcherSearchText = "fire";
        compare(output.filteredLauncherEntries.length, 1);
        compare(output.filteredLauncherEntries[0].id, "org.mozilla.firefox.desktop");
        verify(output.launchEntry("org.mozilla.firefox.desktop"));
        compare(JSON.stringify(fixture.commands.sent), JSON.stringify([{
            family: "launcher",
            command: {type: "launch", data: {schemaVersion: 2,
                desktopId: "org.mozilla.firefox.desktop", resources: []}}
        }]));
        verify(!output.launchEntry("missing.desktop"));
        verify(!output.launchAction("org.mozilla.firefox.desktop", "open"));
        verify(!output.launcherCalculatorSupported);
        verify(!output.launcherCommandModeSupported);
        compare(fixture.commands.sent.length, 1);
        compare(output.activeOverlay, "launcher");

        const button = findChild(output, "launcherEntry:org.mozilla.firefox.desktop");
        verify(button !== null, "confirmed launcher delegate was not instantiated");
        verify(button.enabled, "confirmed launcher delegate was disabled");
        verify(button.activeFocusOnTab, "enabled launcher delegate left the tab chain");
        verify(button.Accessible.name.indexOf("Firefox") >= 0);
        fixture.commands.busy = true;
        wait(0);
        verify(!button.enabled && !button.activeFocusOnTab);
        compare(button.Accessible.description, "Another desktop command is pending");
        fixture.commands.busy = false;
    }

    function test_notification_center_routes_dnd_actions_and_archive_without_optimism() {
        const fixture = setup();
        const output = outputById(fixture.view, "DP-1");
        output.openOverlay("notifications");
        const dndControl = findChild(output, "notificationDnd");
        const closeControl = findChild(output, "overlayClose");
        verify(dndControl !== null && closeControl !== null);
        output.closeOverlay();
        const trigger = findChild(output, "overlayTrigger:notifications");
        trigger.forceActiveFocus();
        trigger.Accessible.pressAction();
        tryVerify(function() { return dndControl.activeFocus; });
        compare(output.notificationItems.length, 1);
        compare(output.toastItems.length, 1);
        verify(!output.dndEnabled);
        verify(output.setDnd(true));
        verify(!output.dndEnabled);
        verify(!output.invokeNotificationAction("01", "open"));
        verify(!output.archiveNotification(true));
        compare(fixture.commands.sent.length, 1);
        verify(output.invokeNotificationAction(1, "open"));
        verify(output.archiveNotification(1));
        compare(output.notificationItems.length, 1);
        compare(JSON.stringify(fixture.commands.sent), JSON.stringify([
            {family: "notification", command: {type: "setDnd", data: {enabled: true}}},
            {family: "notification", command: {type: "invokeAction", data: {
                notificationId: 1, actionId: "open"}}},
            {family: "notification", command: {type: "archive", data: {notificationId: 1}}}
        ]));
        compare(output.activeOverlay, "notifications");
        const action = findChild(output, "notificationAction:1:open");
        verify(action !== null, "confirmed notification action was not instantiated");
        verify(action.enabled, "confirmed notification action was disabled");
        verify(action.activeFocusOnTab, "enabled notification action left the tab chain");
        compare(action.Accessible.role, Accessible.Button);
        fixture.commands.busy = true;
        wait(0);
        tryVerify(function() { return closeControl.activeFocus; });
        compare(findChild(output, "notificationDnd").Accessible.description,
            "Another desktop command is pending");
        compare(action.Accessible.description, "Another desktop command is pending");
        fixture.commands.busy = false;

        const confirmedDnd = fixtureSnapshot();
        confirmedDnd.notifications.dnd = true;
        accept(fixture.model, confirmedDnd, 2);
        verify(output.dndEnabled);
        compare(output.toastItems.length, 0);
    }

    function test_unavailable_launcher_disables_launch_but_notifications_remain_usable() {
        const model = loadProductionModel();
        const degraded = fixtureSnapshot();
        degraded.launcher.availability = {status: "unsupported",
            diagnostic: {message: "Launcher unavailable"}};
        accept(model, degraded, 1);
        const commands = createTemporaryObject(commandSinkFactory, testCase);
        const output = outputById(createView(model, commands), "DP-1");
        verify(!output.launcherAvailable);
        verify(output.notificationsAvailable);
        verify(!output.launchEntry("org.mozilla.firefox.desktop"));
        compare(commands.sent.length, 0);
        verify(output.setDnd(true));
        compare(commands.sent.length, 1);
        output.openOverlay("launcher");
        const button = findChild(output, "launcherEntry:org.mozilla.firefox.desktop");
        verify(button !== null && !button.enabled && !button.activeFocusOnTab);
        verify(button.Accessible.description.indexOf("unavailable") >= 0);
    }

    function test_notification_overlay_focus_falls_back_to_close_when_dnd_is_disabled() {
        const model = loadProductionModel();
        const degraded = fixtureSnapshot();
        degraded.notifications.availability = {status: "unsupported",
            diagnostic: {message: "Notifications unavailable"}};
        accept(model, degraded, 1);
        const commands = createTemporaryObject(commandSinkFactory, testCase);
        const output = outputById(createView(model, commands), "DP-1");
        const trigger = findChild(output, "overlayTrigger:notifications");
        verify(trigger !== null);
        trigger.forceActiveFocus();
        tryVerify(function() { return trigger.activeFocus; });
        trigger.Accessible.pressAction();
        compare(output.activeOverlay, "notifications");
        const closeButton = findChild(output, "overlayClose");
        verify(closeButton !== null);
        const overlay = findChild(output, "coreOverlayView");
        verify(overlay !== null);
        compare(overlay.initialFocusItem, closeButton);
        verify(closeButton.enabled && closeButton.activeFocusOnTab);
        tryVerify(function() { return closeButton.activeFocus; });

        output.closeOverlay();
        accept(model, fixtureSnapshot(), 2);
        commands.busy = true;
        trigger.forceActiveFocus();
        trigger.Accessible.pressAction();
        compare(output.activeOverlay, "notifications");
        tryVerify(function() { return closeButton.activeFocus; });
    }
}
