// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0
import QtTest 1.0

TestCase {
    id: testCase
    name: "DesktopModels"

    property var trackedCellMap: null

    Component {
        id: bindingProbeFactory

        QtObject {
            required property var model
            property real monitorWidth: model.focusedMonitor?.width ?? 0
            property string workspaceName: model.focusedWorkspace?.name ?? ""
            property string windowTitle: model.focusedWindow?.title ?? ""
        }
    }

    Component {
        id: retainedRowProbeFactory

        QtObject {
            required property var row
            property string rowId: row.id
            property string rowName: row.ssid
            property real rowSignalLevel: row.signalLevel
        }
    }

    Component {
        id: optionalFieldProbeFactory

        QtObject {
            required property var model
            property string notificationSummary: model.notifications[0]?.summary ?? ""
            property int notificationTimeoutMs: model.notifications[0]?.timeoutMs ?? -1
            property string calendarSummary: model.calendarEvents[0]?.summary ?? ""
            property string calendarLocation: model.calendarEvents[0]?.location ?? ""
        }
    }

    Component { id: signalSpy; SignalSpy {} }

    function loadProductionModel() {
        const component = Qt.createComponent("../../src/services/DesktopModelProjection.qml");
        verify(component.status === Component.Ready, component.errorString());
        return createTemporaryObject(component, testCase);
    }

    function makeTrackedCellMap() {
        const map = new Map();
        return {
            "size": 0,
            "get": function(target) {
                return map.get(target);
            },
            "set": function(target, value) {
                if (!map.has(target))
                    this.size += 1;
                map.set(target, value);
            },
            "delete": function(target) {
                if (!map.delete(target))
                    return false;
                this.size -= 1;
                return true;
            }
        };
    }

    function loadProductionModelWithTrackedCellMap() {
        let qml = source("../../src/services/DesktopModelProjection.qml");
        const original = "const cells = new Map();";
        verify(qml.indexOf(original) >= 0);
        testCase.trackedCellMap = makeTrackedCellMap();
        qml = qml.replace(original, "const cells = testCase.trackedCellMap;");
        const object = Qt.createQmlObject(qml, testCase, "TrackedMapDesktopModelProjection");
        verify(object !== null);
        return object;
    }

    function loadProductionProtocol() {
        const component = Qt.createComponent("../../src/services/DesktopProtocol.qml");
        verify(component.status === Component.Ready, component.errorString());
        return createTemporaryObject(component, testCase);
    }

    function available(data) {
        return {"status": "available", "data": data};
    }

    function unavailable(message) {
        return {"status": "unsupported", "diagnostic": {"message": message}};
    }

    function snapshot() {
        return {
            "system": {
                "network": available({"wifiEnabled": true, "scanning": false,
                    "accessPoints": [
                        {"id": "ap-home", "ssid": "Home", "signalLevel": 0.8, "secured": true},
                        {"id": "ap-office", "ssid": "Office", "signalLevel": 0.5, "secured": true}
                    ],
                    "connections": [{"id": "wifi-home", "name": "Home", "kind": "wifi", "connected": true}]}),
                "bluetooth": available({"powered": true, "scanning": false,
                    "devices": [{"id": "headset", "name": "Headset", "paired": true, "connected": true}]}),
                "audio": available({
                    "nodes": [
                        {"id": "speaker", "name": "Speakers", "kind": "output", "volume": 0.7, "muted": false, "isDefault": true},
                        {"id": "mic", "name": "Microphone", "kind": "input", "volume": 0.4, "muted": false, "isDefault": true}
                    ],
                    "streams": [{"id": "music", "name": "Music", "nodeId": "speaker", "volume": 0.6, "muted": false}]
                }),
                "media": available({"players": [{"id": "player", "identity": "org.player", "title": "Song", "artist": "Artist", "playing": true, "progress": 0.4}]}),
                "battery": available({"level": 0.82, "charging": false, "secondsRemaining": 4200}),
                "brightness": available({"level": 0.65}),
                "nightLight": available({"enabled": false}),
                "power": available({"activeProfile": "balanced", "availableProfiles": ["power-saver", "balanced", "performance"]}),
                "osd": available({"current": {"schemaVersion": 2, "outputId": "speaker", "kind": "volume", "level": 0.7, "muted": false, "label": "Volume"}, "history": []}),
                "lock": available({"secure": true})
            },
            "compositor": {"hyprland": available({
                "actionCapabilities": {"focusWindow": true, "moveWindowToWorkspace": true, "closeWindow": true,
                    "focusWorkspace": true, "moveWorkspaceToMonitor": true, "toggleFullscreen": true,
                    "toggleFloating": true, "togglePinned": true, "toggleGroup": true, "exit": true},
                "monitors": [
                    {"id": "m1", "name": "eDP-1", "width": 1920, "height": 1080, "scale": 1, "focused": true},
                    {"id": "m2", "name": "HDMI-A-1", "width": 2560, "height": 1440, "scale": 1, "focused": false}
                ],
                "workspaces": [
                    {"id": "1", "name": "1", "monitorId": "m1", "focused": true},
                    {"id": "special", "name": "special:music", "monitorId": "m1", "focused": false},
                    {"id": "2", "name": "2", "monitorId": "m2", "focused": false}
                ],
                "windows": [
                    {"id": "w1", "title": "Terminal", "applicationId": "terminal", "workspaceId": "1", "focused": true, "fullscreen": true, "floating": false, "pinned": false, "grouped": false},
                    {"id": "w2", "title": "Browser", "applicationId": "browser", "workspaceId": "2", "focused": false, "fullscreen": false, "floating": false, "pinned": false, "grouped": false}
                ]
            })},
            "notifications": {"availability": {"status": "available"}, "dnd": false, "active": [
                {"schemaVersion": 2, "id": 7, "applicationId": "org.sleepy.Test", "summary": "Ready", "body": "Body",
                    "urgency": "normal", "createdAt": "2026-08-31T01:00:00Z", "read": false, "archived": false,
                    "actions": [{"id": "open", "label": "Open", "state": "available"}]}
            ]},
            "launcher": {"availability": {"status": "available"}, "entries": [
                {"id": "org.sleepy.Test.desktop", "name": "Sleepy Test", "icon": "sleepy"}
            ]},
            "calendar": {"availability": {"status": "available"}, "snapshot": {
                "schemaVersion": 2, "providerId": "local", "windowStart": "2026-08-31T00:00:00Z",
                "windowEnd": "2026-09-01T00:00:00Z", "sourceErrors": [], "events": [
                {"id": "event-1", "summary": "Standup", "startsAt": "2026-08-31T09:00:00Z", "endsAt": "2026-08-31T09:30:00Z", "allDay": false, "sourceId": "local"}
            ]}},
            "weather": {"availability": {"status": "available"}, "snapshot": {
                "schemaVersion": 2, "providerId": "weather", "location": {"displayName": "Prague", "latitude": 50.0755, "longitude": 14.4378},
                "status": "online", "cache": "fresh", "attribution": "Test fixture", "forecast": [
                {"at": "2026-08-31T12:00:00Z", "temperatureC": 22.5, "symbol": "clear"}
            ]}},
            "appearance": {"availability": {"status": "available"}, "wallpaperId": "moon", "theme": {
                "schemaVersion": 1, "id": "018f3f4c-8af1-7f6b-bf42-1bd472868e67", "name": "Default", "origin": "builtin", "appearance": "dark",
                "effects": "full", "reducedMotion": false, "opaqueFallback": false,
                "colors": {"background": "#000000", "surface": "#111111", "textPrimary": "#ffffff",
                    "textSecondary": "#d0d0d0", "accent": "#66ccff", "control": "#eeeeee"}
            }},
            "resources": {"availability": {"status": "available"}, "samples": [
                {"id": "cpu", "cpuUsage": 0.4, "memoryUsage": 0.5, "loadOne": 1.1}
            ]},
            "utilities": {
                "trayItems": available([{"id": "tray-1", "title": "Tray", "menu": {"id": "root", "label": "Root", "enabled": true, "children": []}}]),
                "clipboardEntries": available([]), "recording": available({"status": "inactive"}),
                "idleInhibited": available(false), "gameMode": available(false),
                "screenshot": {"status": "available"}, "colorPicker": {"status": "available"}
            }
        };
    }

    function clone(value) { return JSON.parse(JSON.stringify(value)); }

    function source(relativePath) {
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl(relativePath), false);
        request.send();
        return request.responseText;
    }

    function sdkFullSnapshotEnvelope() {
        return JSON.parse(source("../fixtures/task7b-sdk-full-snapshot.json"));
    }

    function strictDomainEnvelope(generation, topic, update) {
        return {
            "schemaVersion": 3,
            "generation": generation,
            "eventId": "22222222-2222-4222-8222-222222222222",
            "emittedAt": "2026-08-31T12:00:00Z",
            "cause": {"kind": "external"},
            "payload": {
                "type": "domainUpdate",
                "data": {"topic": topic, "update": update}
            }
        };
    }

    function acceptAndProject(protocol, model, generation, topic, update) {
        verify(protocol.acceptEnvelope(strictDomainEnvelope(generation, topic, update)),
               protocol.diagnostic);
        verify(model.applyDomainUpdate(topic, protocol.snapshot[topic], protocol.generation));
    }

    function loadProductionModelObjectGraph() {
        let qml = source("../../src/services/DesktopModel.qml");
        qml = qml.replace("pragma Singleton", "");
        qml = qml.replace("\"DesktopModelPrivate.js\"", "\"../../src/services/DesktopModelPrivate.js\"");
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
        const object = Qt.createQmlObject(qml, testCase, "ProductionDesktopModelAudit");
        verify(object !== null);
        return object;
    }

    function loadPrivateLibraryAttacker() {
        const qml = `
            import QtQuick 6.0
            import "../../src/services/DesktopModelPrivate.js" as Internal

            QtObject {
                readonly property Component maliciousFactory: Component {
                    QtObject {
                        property bool available: true
                        property string connectionState: "ready"
                        property string diagnostic: ""
                        property int generation: 777
                        property var snapshot: ({"injected": true})
                        property var accessPoints: [{"id": "first-writer"}]

                        function setConnectionState(_state, _diagnostic) {}
                        function applyFullSnapshot(document, confirmedGeneration) {
                            snapshot = document;
                            generation = confirmedGeneration;
                            accessPoints = document.system?.network?.data?.accessPoints || [];
                            return true;
                        }
                    }
                }

                function preinitialize() { return Internal.initialize(maliciousFactory); }
                function inject(document) {
                    return Internal.synchronize("ready", "", document, 999, true);
                }
            }
        `;
        try {
            return Qt.createQmlObject(qml, testCase, "DesktopModelPrivateAttack");
        } catch (_error) {
            return null;
        }
    }

    function publicRows(model) {
        const names = ["monitors", "workspaces", "windows", "accessPoints", "connections",
                       "bluetoothDevices", "audioNodes", "audioStreams", "players", "notifications",
                       "launcherEntries", "trayItems", "clipboardEntries", "calendarEvents",
                       "weatherForecast", "resourceSamples"];
        const rows = [];
        for (const name of names) {
            verify(model[name].length > 0, name);
            rows.push({"collection": name, "row": model[name][0]});
        }
        return rows;
    }

    function productionProjectionUsesWeakMap(qml) {
        return /\bWeakMap\b/.test(qml);
    }

    function livePresentationRowCount(model) {
        const names = ["monitors", "workspaces", "windows", "accessPoints", "connections",
                       "bluetoothDevices", "audioNodes", "audioStreams", "players", "notifications",
                       "launcherEntries", "trayItems", "clipboardEntries", "calendarEvents",
                       "weatherForecast", "resourceSamples"];
        return names.reduce((total, name) => total + model[name].length, 0);
    }

    function test_production_projection_forbids_weakmap_mutation() {
        const qml = source("../../src/services/DesktopModelProjection.qml");
        verify(!productionProjectionUsesWeakMap(qml));
        const mutant = qml.replace("new Map()", "new WeakMap()");
        verify(productionProjectionUsesWeakMap(mutant));
    }

    function test_sustained_projection_keeps_identity_and_bounds_cell_lifetime() {
        const model = loadProductionModelWithTrackedCellMap();
        const initial = snapshot();
        verify(model.applyFullSnapshot(initial, 1));
        compare(testCase.trackedCellMap.size, livePresentationRowCount(model));
        let retainedHome = model.accessPoints[0];

        for (let iteration = 0; iteration < 250; ++iteration) {
            const full = clone(initial);
            full.system.network.data.accessPoints[0].signalLevel = iteration / 250;
            if (iteration % 2 === 0) {
                full.system.network.data.accessPoints.push({
                    "id": "ephemeral-" + iteration,
                    "ssid": "Ephemeral " + iteration,
                    "signalLevel": 0.25,
                    "secured": false
                });
            }
            verify(model.applyFullSnapshot(full, iteration * 2 + 2));
            compare(model.accessPoints[0], retainedHome);
            compare(model.accessPoints[0].signalLevel, iteration / 250);
            compare(testCase.trackedCellMap.size, livePresentationRowCount(model));

            const network = clone(full.system.network);
            network.data.accessPoints[0].signalLevel = (iteration + 1) / 250;
            verify(model.applyDomainUpdate("system",
                {"domain": "network", "data": network}, iteration * 2 + 3));
            compare(model.accessPoints[0], retainedHome);
            compare(model.accessPoints[0].signalLevel, (iteration + 1) / 250);
            compare(testCase.trackedCellMap.size, livePresentationRowCount(model));
            if (typeof gc === "function" && iteration % 10 === 0)
                gc();
        }

        const retiredHome = retainedHome;
        const withoutAccessPoints = clone(initial.system.network);
        withoutAccessPoints.data.accessPoints = [];
        verify(model.applyDomainUpdate("system",
            {"domain": "network", "data": withoutAccessPoints}, 1000));
        compare(model.accessPoints.length, 0);
        compare(testCase.trackedCellMap.size, livePresentationRowCount(model));
        compare(retiredHome.id, "ap-home");

        const readded = clone(withoutAccessPoints);
        readded.data.accessPoints = [{
            "id": "ap-home", "ssid": "Home Again", "signalLevel": 0.95, "secured": true
        }];
        verify(model.applyDomainUpdate("system", {"domain": "network", "data": readded}, 1001));
        retainedHome = model.accessPoints[0];
        verify(retainedHome !== retiredHome);
        compare(retainedHome.ssid, "Home Again");
        compare(retiredHome.ssid, "Home");
        compare(testCase.trackedCellMap.size, livePresentationRowCount(model));
    }

    function throwingProjectionRecord(identifier) {
        const record = {"id": identifier};
        Object.defineProperty(record, "ssid", {
            "enumerable": true,
            "get": function() {
                throw new Error("synthetic projection record failure");
            }
        });
        return record;
    }

    function test_failed_reconciliation_never_retains_staged_new_handles() {
        const model = loadProductionModelWithTrackedCellMap();
        verify(model.applyFullSnapshot(snapshot(), 1));
        const beforeSize = testCase.trackedCellMap.size;
        const beforeRows = model.accessPoints;

        for (let iteration = 0; iteration < 100; ++iteration) {
            let threw = false;
            try {
                model.reconcileRows("accessPoints", [
                    {"id": "new-" + iteration, "ssid": "New", "signalLevel": 0.4,
                        "secured": false},
                    throwingProjectionRecord("throwing-" + iteration)
                ], "id");
            } catch (_error) {
                threw = true;
            }
            verify(threw, "iteration " + iteration);
            compare(model.accessPoints, beforeRows, "iteration " + iteration);
            if (typeof gc === "function" && iteration % 10 === 0)
                gc();
        }

        compare(testCase.trackedCellMap.size, beforeSize);
    }

    function test_failed_reconciliation_never_partially_updates_existing_cells() {
        const model = loadProductionModelWithTrackedCellMap();
        verify(model.applyFullSnapshot(snapshot(), 1));
        const home = model.accessPoints[0];
        const beforeRows = model.accessPoints;
        const beforeSize = testCase.trackedCellMap.size;

        let threw = false;
        try {
            model.reconcileRows("accessPoints", [
                {"id": "new-before-failure", "ssid": "New", "signalLevel": 0.4,
                    "secured": false},
                {"id": "ap-home", "ssid": "Partially updated", "signalLevel": 0.01,
                    "secured": true},
                throwingProjectionRecord("throwing-after-existing")
            ], "id");
        } catch (_error) {
            threw = true;
        }

        verify(threw);
        compare(model.accessPoints, beforeRows);
        compare(model.accessPoints[0], home);
        compare(home.ssid, "Home");
        compare(home.signalLevel, 0.8);
        compare(testCase.trackedCellMap.size, beforeSize);
    }

    function reachableRowBacking(row) {
        const candidates = [row];
        const visited = [];
        while (candidates.length > 0) {
            const candidate = candidates.shift();
            if (!candidate || (typeof candidate !== "object" && typeof candidate !== "function")
                    || visited.indexOf(candidate) >= 0)
                continue;
            visited.push(candidate);
            if (candidate !== row && (candidate.record !== undefined
                    || candidate.revision !== undefined || candidate.disposed !== undefined
                    || typeof candidate.destroy === "function"))
                return candidate;
            const names = Object.getOwnPropertyNames(candidate);
            for (const name of names) {
                let value;
                try { value = candidate[name]; } catch (_error) { continue; }
                if (value && (typeof value === "object" || typeof value === "function"))
                    candidates.push(value);
            }
            for (const symbol of Object.getOwnPropertySymbols(candidate)) {
                let value;
                try { value = candidate[symbol]; } catch (_error) { continue; }
                if (value && (typeof value === "object" || typeof value === "function"))
                    candidates.push(value);
            }
        }
        return null;
    }

    function falseActionCapabilities() {
        return {
            "focusWindow": false,
            "moveWindowToWorkspace": false,
            "closeWindow": false,
            "focusWorkspace": false,
            "moveWorkspaceToMonitor": false,
            "toggleFullscreen": false,
            "toggleFloating": false,
            "togglePinned": false,
            "toggleGroup": false,
            "exit": false
        };
    }

    function test_identity_preserving_updates_notify_direct_field_bindings_once() {
        const model = loadProductionModel();
        const initial = snapshot();
        model.applyFullSnapshot(initial, 1);
        const monitor = model.focusedMonitor;
        const workspace = model.focusedWorkspace;
        const window = model.focusedWindow;
        const probe = createTemporaryObject(bindingProbeFactory, testCase, {"model": model});
        const monitorSpy = signalSpy.createObject(testCase, {"target": probe, "signalName": "monitorWidthChanged"});
        const workspaceSpy = signalSpy.createObject(testCase, {"target": probe, "signalName": "workspaceNameChanged"});
        const windowSpy = signalSpy.createObject(testCase, {"target": probe, "signalName": "windowTitleChanged"});

        const compositor = clone(initial.compositor.hyprland);
        compositor.data.monitors[0].width = 1600;
        compositor.data.workspaces[0].name = "main";
        compositor.data.windows[0].title = "Updated Terminal";
        model.applyDomainUpdate("compositor", {"domain": "hyprland", "data": compositor}, 2);

        compare(model.focusedMonitor, monitor);
        compare(model.focusedWorkspace, workspace);
        compare(model.focusedWindow, window);
        compare(probe.monitorWidth, 1600);
        compare(probe.workspaceName, "main");
        compare(probe.windowTitle, "Updated Terminal");
        compare(monitorSpy.count, 1);
        compare(workspaceSpy.count, 1);
        compare(windowSpy.count, 1);
    }

    function test_strict_notification_optional_timeout_preserves_identity_and_bindings() {
        const protocol = loadProductionProtocol();
        const model = loadProductionModel();
        const full = sdkFullSnapshotEnvelope();
        verify(protocol.acceptEnvelope(full), protocol.diagnostic);
        verify(model.applyFullSnapshot(protocol.snapshot, protocol.generation));
        const notification = model.notifications[0];
        const probe = createTemporaryObject(optionalFieldProbeFactory, testCase,
            {"model": model});
        const summarySpy = signalSpy.createObject(testCase,
            {"target": probe, "signalName": "notificationSummaryChanged"});
        const timeoutSpy = signalSpy.createObject(testCase,
            {"target": probe, "signalName": "notificationTimeoutMsChanged"});
        compare(probe.notificationTimeoutMs, -1);

        const withTimeout = clone(protocol.snapshot.notifications);
        withTimeout.active[0].summary = "Ready with timeout";
        withTimeout.active[0].timeoutMs = 5000;
        acceptAndProject(protocol, model, 8, "notifications", withTimeout);
        wait(0);
        compare(model.notifications[0], notification);
        compare(notification.summary, "Ready with timeout");
        compare(notification.timeoutMs, 5000);
        compare(probe.notificationSummary, "Ready with timeout");
        compare(probe.notificationTimeoutMs, 5000);
        compare(summarySpy.count, 1);
        compare(timeoutSpy.count, 1);
        verify(Object.isFrozen(notification));

        const withoutTimeout = clone(protocol.snapshot.notifications);
        withoutTimeout.active[0].summary = "Ready without timeout";
        delete withoutTimeout.active[0].timeoutMs;
        acceptAndProject(protocol, model, 9, "notifications", withoutTimeout);
        wait(0);
        compare(model.notifications[0], notification);
        compare(notification.summary, "Ready without timeout");
        compare(notification.timeoutMs, undefined);
        compare(probe.notificationSummary, "Ready without timeout");
        compare(probe.notificationTimeoutMs, -1);
        compare(summarySpy.count, 2);
        compare(timeoutSpy.count, 2);

        const removed = clone(protocol.snapshot.notifications);
        removed.active = [];
        acceptAndProject(protocol, model, 10, "notifications", removed);
        compare(model.notifications.length, 0);
        const readded = clone(withoutTimeout);
        readded.active[0].summary = "Re-added";
        acceptAndProject(protocol, model, 11, "notifications", readded);
        verify(model.notifications[0] !== notification);
        compare(model.notifications[0].id, 1);
    }

    function test_strict_calendar_optional_location_preserves_identity_and_bindings() {
        const protocol = loadProductionProtocol();
        const model = loadProductionModel();
        const full = sdkFullSnapshotEnvelope();
        verify(protocol.acceptEnvelope(full), protocol.diagnostic);
        verify(model.applyFullSnapshot(protocol.snapshot, protocol.generation));
        const calendarEvent = model.calendarEvents[0];
        const probe = createTemporaryObject(optionalFieldProbeFactory, testCase,
            {"model": model});
        const summarySpy = signalSpy.createObject(testCase,
            {"target": probe, "signalName": "calendarSummaryChanged"});
        const locationSpy = signalSpy.createObject(testCase,
            {"target": probe, "signalName": "calendarLocationChanged"});
        compare(probe.calendarLocation, "");

        const withLocation = clone(protocol.snapshot.calendar);
        withLocation.snapshot.events[0].summary = "Meeting in person";
        withLocation.snapshot.events[0].location = "Office";
        acceptAndProject(protocol, model, 8, "calendar", withLocation);
        wait(0);
        compare(model.calendarEvents[0], calendarEvent);
        compare(calendarEvent.summary, "Meeting in person");
        compare(calendarEvent.location, "Office");
        compare(probe.calendarSummary, "Meeting in person");
        compare(probe.calendarLocation, "Office");
        compare(summarySpy.count, 1);
        compare(locationSpy.count, 1);
        verify(Object.isFrozen(calendarEvent));

        const withoutLocation = clone(protocol.snapshot.calendar);
        withoutLocation.snapshot.events[0].summary = "Meeting remote";
        delete withoutLocation.snapshot.events[0].location;
        acceptAndProject(protocol, model, 9, "calendar", withoutLocation);
        wait(0);
        compare(model.calendarEvents[0], calendarEvent);
        compare(calendarEvent.summary, "Meeting remote");
        compare(calendarEvent.location, undefined);
        compare(probe.calendarSummary, "Meeting remote");
        compare(probe.calendarLocation, "");
        compare(summarySpy.count, 2);
        compare(locationSpy.count, 2);

        const removed = clone(protocol.snapshot.calendar);
        removed.snapshot.events = [];
        acceptAndProject(protocol, model, 10, "calendar", removed);
        compare(model.calendarEvents.length, 0);
        const readded = clone(withoutLocation);
        readded.snapshot.events[0].summary = "Re-added meeting";
        acceptAndProject(protocol, model, 11, "calendar", readded);
        verify(model.calendarEvents[0] !== calendarEvent);
        compare(model.calendarEvents[0].id, "meeting@example");
    }

    function test_importable_helpers_cannot_publish_or_retain_desktop_state() {
        const attacker = loadPrivateLibraryAttacker();
        if (attacker)
            verify(attacker.preinitialize());

        let productionModel = loadProductionModelObjectGraph();
        const injected = snapshot();
        injected.system.network.data.accessPoints = [
            {"id": "injected", "ssid": "Injected", "signalLevel": 1, "secured": false}
        ];
        if (attacker)
            attacker.inject(injected);
        if (productionModel.modelFacade
                && typeof productionModel.modelFacade.synchronize === "function")
            productionModel.modelFacade.synchronize("ready", "", injected, 999, true);
        productionModel.modelRevision += 1;

        compare(productionModel.connectionState, "offline");
        compare(productionModel.generation, 0);
        compare(productionModel.accessPoints.length, 0);
        productionModel.destroy();
        wait(0);

        productionModel = loadProductionModelObjectGraph();
        compare(productionModel.connectionState, "offline");
        compare(productionModel.generation, 0);
        compare(productionModel.accessPoints.length, 0);
    }

    function test_public_rows_are_frozen_and_expose_no_forgeable_backing_state() {
        const model = loadProductionModel();
        const initial = snapshot();
        initial.utilities.clipboardEntries = available([
            {"id": "clipboard-1", "mimeType": "text/plain", "preview": "Copied"}
        ]);
        model.applyFullSnapshot(initial, 1);

        for (const entry of publicRows(model)) {
            const row = entry.row;
            const identifier = row.id ?? row.at;
            const backing = reachableRowBacking(row);
            if (backing) {
                try { backing.record = Object.freeze({"id": "forged", "at": "forged"}); }
                catch (_error) {}
                try { backing.revision = Number(backing.revision || 0) + 1; }
                catch (_error) {}
                try { backing.disposed = true; } catch (_error) {}
            }
            compare(row.id ?? row.at, identifier, entry.collection);
            compare(backing, null, entry.collection);
            verify(Object.isFrozen(row), entry.collection);
            compare(Object.getOwnPropertySymbols(row).length, 0, entry.collection);
            try { row.id = "forged"; } catch (_error) {}
            compare(row.id ?? row.at, identifier, entry.collection);
        }
        compare(model.generation, 1);
        compare(model.snapshot.system.network.data.accessPoints[0].id, "ap-home");
    }

    function test_removed_row_remains_readable_and_readd_gets_fresh_identity() {
        const model = loadProductionModel();
        const initial = snapshot();
        model.applyFullSnapshot(initial, 1);
        const retired = model.accessPoints[1];
        const probe = createTemporaryObject(retainedRowProbeFactory, testCase, {"row": retired});

        const withoutOffice = clone(initial.system.network);
        withoutOffice.data.accessPoints = [withoutOffice.data.accessPoints[0]];
        model.applyDomainUpdate("system", {"domain": "network", "data": withoutOffice}, 2);
        wait(0);
        compare(retired.id, "ap-office");
        compare(retired.ssid, "Office");
        compare(retired.signalLevel, 0.5);
        compare(probe.rowId, "ap-office");
        compare(probe.rowName, "Office");
        compare(probe.rowSignalLevel, 0.5);
        verify(model.accessPoints.indexOf(retired) < 0);

        const withOfficeAgain = clone(withoutOffice);
        withOfficeAgain.data.accessPoints.push(
            {"id": "ap-office", "ssid": "Office Rejoined", "signalLevel": 0.7, "secured": true});
        model.applyDomainUpdate("system", {"domain": "network", "data": withOfficeAgain}, 3);
        const readded = model.accessPoints[1];
        verify(readded !== retired);
        compare(readded.id, "ap-office");
        compare(readded.ssid, "Office Rejoined");
        compare(retired.ssid, "Office");
        verify(Object.isFrozen(retired));
        verify(Object.isFrozen(readded));
    }

    function test_production_singleton_does_not_expose_projection_or_state_mutators() {
        const qml = source("../../src/services/DesktopModel.qml");
        verify(!/property\s+DesktopModelProjection\s+projection\b/.test(qml));
        for (const name of ["applyFullSnapshot", "applyDomainUpdate", "setConnectionState",
                            "clearAuthorityDerivedState", "reconcileConfirmedLists", "replaceRecord"])
            verify(qml.indexOf("function " + name + "(") < 0, name);
    }

    function test_production_singleton_object_graph_has_no_reachable_state_mutator() {
        const productionModel = loadProductionModelObjectGraph();
        const candidates = [productionModel];
        for (const propertyName of ["children", "data"]) {
            const values = productionModel[propertyName];
            if (values && typeof values.length === "number") {
                for (let index = 0; index < values.length; index++)
                    candidates.push(values[index]);
            }
        }
        for (const candidate of candidates) {
            if (!candidate)
                continue;
            for (const name of ["applyFullSnapshot", "applyDomainUpdate", "setConnectionState",
                                "clearAuthorityDerivedState", "reconcileConfirmedLists", "replaceRecord"])
                compare(typeof candidate[name], "undefined", name);
        }
    }

    function test_public_capability_paths_cannot_expose_projection_members() {
        const productionModel = loadProductionModelObjectGraph();
        const initialSnapshot = JSON.stringify(productionModel.snapshot);
        const initialGeneration = productionModel.generation;
        const initialRevision = productionModel.modelRevision;
        const projectionNames = [
            "reconcileRows", "applyFullSnapshot", "applyDomainUpdate", "setConnectionState",
            "clearAuthorityDerivedState", "snapshot", "monitors", "workspaces", "windows",
            "rowRevision", "__proto__", "prototype", "constructor", "call", "apply"
        ];
        const metaKeys = ["prototype", "constructor", "call", "apply", "__proto__"];
        const sentinel = Object.freeze({"sentinel": true});

        for (const section of projectionNames) {
            for (const key of metaKeys) {
                const record = productionModel.capability(section, key);
                compare(record.status, "unavailable", section + ":" + key);
                verify(Object.isFrozen(record), section + ":" + key);
                compare(Object.getPrototypeOf(record), null, section + ":" + key);
                compare(record.constructor, undefined, section + ":" + key);
                compare(productionModel.capabilityData(section, key, sentinel), sentinel,
                        section + ":" + key);
            }
            verify(!productionModel.producerAvailable(section), section);
        }

        compare(JSON.stringify(productionModel.snapshot), initialSnapshot);
        compare(productionModel.generation, initialGeneration);
        compare(productionModel.modelRevision, initialRevision);
        compare(productionModel.monitors.length, 0);
        compare(productionModel.connectionState, "offline");
    }

    function test_nested_presentation_rows_never_alias_source_or_snapshot() {
        const model = loadProductionModel();
        const initial = snapshot();
        const initialText = JSON.stringify(initial);
        model.applyFullSnapshot(initial, 1);
        const acceptedText = JSON.stringify(model.snapshot);
        const notificationRow = model.notifications[0];
        const firstActions = notificationRow.actions;
        verify(firstActions !== model.snapshot.notifications.active[0].actions);
        verify(model.trayItems[0].menu !== model.snapshot.utilities.trayItems.data[0].menu);
        model.notifications[0].actions[0].label = "Mutated presentation";
        model.trayItems[0].menu.children.push({"id": "injected"});
        compare(JSON.stringify(initial), initialText);
        compare(JSON.stringify(model.snapshot), acceptedText);

        const update = clone(initial.notifications);
        update.active[0].actions[0].label = "Confirmed update";
        const updateText = JSON.stringify(update);
        model.applyDomainUpdate("notifications", update, 2);
        const updatedSnapshotText = JSON.stringify(model.snapshot);
        compare(model.notifications[0], notificationRow);
        verify(model.notifications[0].actions !== firstActions);
        verify(model.notifications[0].actions !== model.snapshot.notifications.active[0].actions);
        firstActions[0].label = "Mutated retired presentation";
        model.notifications[0].actions[0].label = "Mutated again";
        compare(JSON.stringify(update), updateText);
        compare(JSON.stringify(model.snapshot), updatedSnapshotText);
        compare(model.snapshot.notifications.active[0].actions[0].label, "Confirmed update");
    }

    function test_granular_compositor_fallback_matches_protocol_false_capabilities() {
        for (const domain of ["monitors", "workspaces", "windows"]) {
            const model = loadProductionModel();
            const initial = snapshot();
            initial.compositor.hyprland = unavailable("Hyprland unavailable");
            model.applyFullSnapshot(initial, 1);
            verify(model.applyDomainUpdate("compositor", {"domain": domain, "data": []}, 2));
            const actual = model.compositor.hyprland.data.actionCapabilities;
            compare(JSON.stringify(actual), JSON.stringify(falseActionCapabilities()), domain);
            compare(Object.keys(actual).length, 10, domain);
            for (const key of Object.keys(falseActionCapabilities()))
                compare(actual[key], false, domain + ":" + key);
        }
    }

    function test_fixture_is_accepted_by_the_production_strict_v3_protocol() {
        const protocol = loadProductionProtocol();
        verify(protocol.acceptEnvelope({
            "schemaVersion": 3,
            "generation": 1,
            "eventId": "018f3f4c-8af1-7f6b-bf42-1bd472868e65",
            "emittedAt": "2026-08-31T12:00:00Z",
            "cause": {"kind": "lifecycle"},
            "payload": {"type": "fullSnapshot", "data": snapshot()}
        }), protocol.diagnostic);
        compare(protocol.connectionState, "ready");
    }

    function test_full_then_incremental_updates_keep_identity_by_id() {
        const model = loadProductionModel();
        const initial = snapshot();
        model.applyFullSnapshot(initial, 1);
        const home = model.accessPoints[0];
        const removedOffice = model.accessPoints[1];
        const connection = model.connections[0];
        const bluetooth = model.bluetoothDevices[0];
        const speaker = model.audioNodes[0];
        const stream = model.audioStreams[0];
        const player = model.players[0];
        const monitor = model.monitors[0];
        const workspace = model.workspaces[0];
        const window = model.windows[0];
        const notification = model.notifications[0];
        const launcher = model.launcherEntries[0];
        const tray = model.trayItems[0];
        const calendar = model.calendarEvents[0];
        const resource = model.resourceSamples[0];

        const network = clone(initial.system.network);
        network.data.accessPoints = [
            {"id": "ap-home", "ssid": "Home", "signalLevel": 0.9, "secured": true},
            {"id": "ap-cafe", "ssid": "Cafe", "signalLevel": 0.3, "secured": false}
        ];
        model.applyDomainUpdate("system", {"domain": "network", "data": network}, 2);
        compare(model.accessPoints[0], home);
        compare(model.connections[0], connection);
        compare(model.accessPoints[0].signalLevel, 0.9);
        compare(model.accessPoints[1].id, "ap-cafe");
        verify(model.accessPoints.indexOf(home) === 0);
        verify(model.accessPoints.indexOf(removedOffice) < 0);

        const audio = clone(initial.system.audio);
        audio.data.nodes[0].volume = 0.25;
        model.applyDomainUpdate("system", {"domain": "audio", "data": audio}, 3);
        compare(model.audioNodes[0], speaker);
        compare(model.audioStreams[0], stream);
        compare(model.audioNodes[0].volume, 0.25);

        const media = clone(initial.system.media);
        media.data.players[0].title = "Next Song";
        model.applyDomainUpdate("system", {"domain": "media", "data": media}, 4);
        compare(model.players[0], player);
        compare(model.players[0].title, "Next Song");

        const bluetoothUpdate = clone(initial.system.bluetooth);
        bluetoothUpdate.data.devices[0].connected = false;
        model.applyDomainUpdate("system", {"domain": "bluetooth", "data": bluetoothUpdate}, 5);
        compare(model.bluetoothDevices[0], bluetooth);
        verify(!model.bluetoothDevices[0].connected);

        const compositor = clone(initial.compositor.hyprland);
        compositor.data.monitors[0].width = 1600;
        compositor.data.workspaces[0].name = "main";
        compositor.data.windows[0].title = "Updated Terminal";
        model.applyDomainUpdate("compositor", {"domain": "hyprland", "data": compositor}, 6);
        compare(model.monitors[0], monitor);
        compare(model.workspaces[0], workspace);
        compare(model.windows[0], window);

        const monitorRows = clone(compositor.data.monitors);
        monitorRows[0].width = 1700;
        model.applyDomainUpdate("compositor", {"domain": "monitors", "data": monitorRows}, 7);
        compare(model.monitors[0], monitor);
        compare(model.monitors[0].width, 1700);
        compare(model.workspaces[0], workspace);
        compare(model.windows[0], window);

        const notifications = clone(initial.notifications);
        notifications.active[0].summary = "Updated";
        model.applyDomainUpdate("notifications", notifications, 8);
        compare(model.notifications[0], notification);
        compare(model.notifications[0].summary, "Updated");

        model.applyDomainUpdate("launcher", clone(initial.launcher), 9);
        model.applyDomainUpdate("utilities", {"domain": "trayItems", "data": clone(initial.utilities.trayItems)}, 10);
        model.applyDomainUpdate("calendar", clone(initial.calendar), 11);
        model.applyDomainUpdate("resources", clone(initial.resources), 12);
        compare(model.launcherEntries[0], launcher);
        compare(model.trayItems[0], tray);
        compare(model.calendarEvents[0], calendar);
        compare(model.resourceSamples[0], resource);
        compare(JSON.stringify(model.monitors.map(item => item.id)), JSON.stringify(["m1", "m2"]));
        compare(JSON.stringify(model.workspaces.map(item => item.id)), JSON.stringify(["1", "special", "2"]));
        compare(JSON.stringify(model.windows.map(item => item.id)), JSON.stringify(["w1", "w2"]));
        compare(JSON.stringify(model.accessPoints.map(item => item.id)), JSON.stringify(["ap-home", "ap-cafe"]));
        compare(JSON.stringify(model.connections.map(item => item.id)), JSON.stringify(["wifi-home"]));
        compare(JSON.stringify(model.bluetoothDevices.map(item => item.id)), JSON.stringify(["headset"]));
        compare(JSON.stringify(model.audioNodes.map(item => item.id)), JSON.stringify(["speaker", "mic"]));
        compare(JSON.stringify(model.audioStreams.map(item => item.id)), JSON.stringify(["music"]));
        compare(JSON.stringify(model.players.map(item => item.id)), JSON.stringify(["player"]));
        compare(JSON.stringify(model.notifications.map(item => item.id)), JSON.stringify([7]));
        compare(JSON.stringify(model.launcherEntries.map(item => item.id)), JSON.stringify(["org.sleepy.Test.desktop"]));
        compare(JSON.stringify(model.trayItems.map(item => item.id)), JSON.stringify(["tray-1"]));
        compare(JSON.stringify(model.calendarEvents.map(item => item.id)), JSON.stringify(["event-1"]));
        compare(JSON.stringify(model.resourceSamples.map(item => item.id)), JSON.stringify(["cpu"]));
        verify(model.accessPoints.find(item => item.id === "ap-office") === undefined);
        compare(model.generation, 12);
        verify(typeof model.command === "undefined");
        verify(typeof model.setVolume === "undefined");
        verify(typeof model.launch === "undefined");
    }

    function test_all_core_domains_project_confirmed_lists() {
        const model = loadProductionModel();
        model.applyFullSnapshot(snapshot(), 1);
        compare(model.monitors.length, 2);
        compare(model.workspaces.length, 3);
        compare(model.windows.length, 2);
        compare(model.bluetoothDevices.length, 1);
        compare(model.audioStreams.length, 1);
        compare(model.calendarEvents.length, 1);
        compare(model.weatherForecast.length, 1);
        compare(model.resourceSamples.length, 1);
        compare(model.trayItems.length, 1);
        compare(model.appearance.wallpaperId, "moon");
    }

    function test_monitor_focus_hotplug_special_occupied_and_fullscreen_are_confirmed() {
        const model = loadProductionModel();
        const initial = snapshot();
        model.applyFullSnapshot(initial, 1);
        compare(model.focusedMonitor.id, "m1");
        compare(model.focusedWorkspaceForMonitor("m1").id, "1");
        compare(model.focusedWindowForMonitor("m1").id, "w1");
        verify(model.monitorHasFullscreen("m1"));
        verify(!model.monitorHasFullscreen("m2"));
        compare(JSON.stringify(model.occupiedWorkspaceIds("m1")), JSON.stringify(["1"]));
        compare(JSON.stringify(model.specialWorkspaceIds("m1")), JSON.stringify(["special"]));

        const compositor = clone(initial.compositor.hyprland);
        compositor.data.monitors = [compositor.data.monitors[1]];
        compositor.data.monitors[0].focused = true;
        compositor.data.workspaces = [compositor.data.workspaces[2]];
        compositor.data.workspaces[0].focused = true;
        compositor.data.windows = [compositor.data.windows[1]];
        compositor.data.windows[0].focused = true;
        model.applyDomainUpdate("compositor", {"domain": "hyprland", "data": compositor}, 2);
        compare(model.monitors.length, 1);
        compare(model.focusedMonitor.id, "m2");
        compare(model.focusedWorkspaceForMonitor("m2").id, "2");
        compare(model.focusedWindowForMonitor("m2").id, "w2");
        compare(model.focusedWorkspaceForMonitor("m1"), null);
        verify(!model.monitorHasFullscreen("m2"));
    }

    function test_disconnect_clears_authority_and_reconnect_replaces_without_stale_rows() {
        const model = loadProductionModel();
        const initial = snapshot();
        model.applyFullSnapshot(initial, 10);
        verify(model.available);
        model.setConnectionState("offline", "daemon disconnected");
        verify(!model.available);
        compare(model.accessPoints.length, 0);
        compare(model.windows.length, 0);
        compare(model.notifications.length, 0);
        compare(model.diagnostic, "daemon disconnected");

        const replacement = snapshot();
        replacement.system.network = unavailable("Network unavailable");
        replacement.system.bluetooth = unavailable("Bluetooth unavailable");
        replacement.system.audio = unavailable("Audio unavailable");
        replacement.system.battery = unavailable("Battery unavailable");
        replacement.weather.availability = {"status": "timeout", "diagnostic": {"message": "Weather timeout"}};
        replacement.weather.snapshot.forecast = [];
        replacement.launcher.entries = [{"id": "org.sleepy.Reconnected.desktop", "name": "Reconnected", "icon": "sleepy"}];
        replacement.compositor.hyprland.data.monitors = [replacement.compositor.hyprland.data.monitors[1]];
        replacement.compositor.hyprland.data.monitors[0].focused = true;
        replacement.compositor.hyprland.data.workspaces = [replacement.compositor.hyprland.data.workspaces[2]];
        replacement.compositor.hyprland.data.windows = [];
        model.applyFullSnapshot(replacement, 12);
        verify(model.available);
        verify(!model.capabilityAvailable("system", "network"));
        verify(!model.capabilityAvailable("system", "bluetooth"));
        verify(!model.capabilityAvailable("system", "audio"));
        verify(!model.capabilityAvailable("system", "battery"));
        verify(!model.producerAvailable("weather"));
        compare(model.capabilityDiagnostic("system", "network"), "Network unavailable");
        compare(model.producerDiagnostic("weather"), "Weather timeout");
        verify(model.capabilityAvailable("system", "brightness"));
        verify(model.producerAvailable("notifications"));
        compare(model.accessPoints.length, 0);
        compare(model.weatherForecast.length, 0);
        compare(JSON.stringify(model.monitors.map(item => item.id)), JSON.stringify(["m2"]));
        compare(JSON.stringify(model.launcherEntries.map(item => item.id)), JSON.stringify(["org.sleepy.Reconnected.desktop"]));
        verify(model.launcherEntries.find(item => item.id === "org.sleepy.Test.desktop") === undefined);
        compare(model.generation, 12);
    }

}
