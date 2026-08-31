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
