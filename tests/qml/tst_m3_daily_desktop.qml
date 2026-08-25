// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0
import QtTest 1.0
import "../../src/services" as Services
import "../../src/theme" as Theme

TestCase {
    id: testCase
    name: "M3DailyDesktop"

    Component { id: eventFactory; Services.SessionEventModel {} }
    Component { id: dailyFactory; Services.DailyProtocol {} }
    Component { id: osdFactory; Services.OsdStreamModel {} }
    Component { id: themeFactory; Services.ThemeProtocol {} }
    Component { id: notificationFactory; Services.NotificationCenterModel {} }
    Component { id: systemAdapterCoreFactory; Services.SystemAdapterCore {} }
    Component { id: registryFactory; Services.SurfaceRegistry {} }
    Component { id: effectsFactory; Theme.EffectsPolicy {} }
    Component { id: paletteFactory; Theme.Palette {} }
    SignalSpy { id: rollbackSpy; signalName: "rollbackRequested" }
    Component {
        id: stateFixtureFactory
        QtObject {
            id: fixture
            property string capabilityStatus: "available"
            property string lastOperation: ""
            property var lastData: null
            readonly property QtObject events: QtObject {
                property string connectionState: "ready"
                property double generation: 12
                signal eventAccepted(var envelope)
                function capability(id) {
                    if (id === "niri" && fixture.capabilityStatus === "available")
                        return {"id": id, "status": "available", "available": true,
                            "diagnostic": "", "value": {"type": "niri", "data": {
                                "outputIds": ["DP-1"], "workspaceIds": [1], "windowIds": [7]}}};
                    return {"id": id, "status": fixture.capabilityStatus,
                        "available": false, "diagnostic": fixture.capabilityStatus, "value": null};
                }
            }
            readonly property QtObject daily: QtObject {
                property string status: "idle"
                property string errorString: ""
                signal responseAccepted(var data)
                function sendRequest(request) {
                    fixture.lastOperation = request.type;
                    fixture.lastData = request.data;
                    return true;
                }
                function launcherSearch(query) { return {"type": "launcher", "data": query}; }
                function geocodeSubmit(query) { return {"type": "geocode", "data": query}; }
                function calendar(start, end) { return {"type": "calendar", "data": [start, end]}; }
                function weather(location) { return {"type": "weather", "data": location}; }
                function overview(command, data) { return {"type": command, "data": data}; }
                function launch(desktopId, actionId) {
                    return {"type": "launch", "data": {"desktopId": desktopId,
                        "actionId": actionId}};
                }
            }
            readonly property Services.DailyDesktopState state: Services.DailyDesktopState {
                events: fixture.events
                daily: fixture.daily
            }
        }
    }

    function envelope(generation, payload, cause) {
        return JSON.stringify({
            "schemaVersion": 2,
            "generation": generation,
            "eventId": "018f3f4c-8af1-7f6b-bf42-1bd472868e62",
            "emittedAt": "2026-08-24T21:00:00Z",
            "cause": cause || {"kind": "replay"},
            "payload": payload
        });
    }

    function unavailable(id) {
        return {"id": id, "status": "unsupported",
                "diagnostic": {"message": "not present"}};
    }

    function fullCapabilities(overrides) {
        const records = [
            unavailable("network"), unavailable("bluetooth"), unavailable("audio"),
            unavailable("battery"), unavailable("brightness"),
            unavailable("powerProfile"), unavailable("media"),
            unavailable("nightLight"), unavailable("niri"), unavailable("resources")
        ];
        Object.keys(overrides || {}).forEach(function(id) {
            const index = records.findIndex(function(record) { return record.id === id; });
            records[index] = overrides[id];
        });
        return records;
    }

    function test_event_stream_requires_snapshot_first_and_monotonic_generation() {
        const model = createTemporaryObject(eventFactory, testCase);
        const update = {"type": "capabilityUpdate", "data": {
            "id": "network", "status": "available", "value": {
                "type": "network", "data": {"wifiEnabled": true,
                    "ethernetConnected": false, "connectivity": "full",
                    "activeConnectionId": "home"}
            }
        }};
        compare(model.acceptLine(envelope(4, update)), false);
        compare(model.connectionState, "error");

        model.beginConnection();
        const snapshot = {"type": "fullSnapshot", "data": {
            "capabilities": fullCapabilities({"network": {
                "id": "network", "status": "unavailable",
                "diagnostic": {"message": "radio missing"}}}),
            "focusedOutputId": "DP-1"
        }};
        compare(model.acceptLine(envelope(5, snapshot)), true);
        compare(model.connectionState, "ready");
        compare(model.focusedOutputId, "DP-1");
        compare(model.capability("network").status, "unavailable");
        compare(model.acceptLine(envelope(5, update)), false);
        compare(model.generation, 5);
        compare(model.acceptLine(envelope(6, update)), true);
        compare(model.capability("network").value.data.wifiEnabled, true);
    }

    function test_capability_failures_remain_local_and_truthful() {
        const model = createTemporaryObject(eventFactory, testCase);
        model.beginConnection();
        const snapshot = {"type": "fullSnapshot", "data": {"capabilities":
            fullCapabilities({
                "network": {"id": "network", "status": "available", "value": {
                    "type": "network", "data": {"wifiEnabled": true,
                        "ethernetConnected": false, "connectivity": "full"}}},
                "bluetooth": {"id": "bluetooth", "status": "permissionDenied",
                    "diagnostic": {"message": "policy denied"}},
                "media": {"id": "media", "status": "unsupported",
                    "diagnostic": {"message": "no players"}}
            })}};
        verify(model.acceptLine(envelope(1, snapshot)));
        compare(model.capability("network").available, true);
        compare(model.capability("bluetooth").available, false);
        compare(model.capability("bluetooth").status, "permissionDenied");
        compare(model.capability("media").status, "unsupported");
        compare(model.connectionState, "ready");
    }

    function test_event_stream_rejects_incomplete_and_mistyped_sdk_snapshots() {
        const incomplete = createTemporaryObject(eventFactory, testCase);
        incomplete.beginConnection();
        compare(incomplete.acceptLine(envelope(1, {"type": "fullSnapshot", "data": {
            "capabilities": [unavailable("network")]
        }})), false);

        const mistyped = createTemporaryObject(eventFactory, testCase);
        mistyped.beginConnection();
        compare(mistyped.acceptLine(envelope(1, {"type": "fullSnapshot", "data": {
            "capabilities": fullCapabilities({"network": {
                "id": "network", "status": "available", "value": {
                    "type": "audio", "data": {"outputLevel": 0.5,
                        "outputMuted": false, "inputLevel": 0.5,
                        "inputMuted": false}
                }
            }})
        }})), false);
    }

    function test_daily_protocol_is_uuid_correlated_and_has_no_arbitrary_exec() {
        const protocol = createTemporaryObject(dailyFactory, testCase);
        const request = protocol.launcherSearch("term", "018f3f4c-8af1-7f6b-bf42-1bd472868e65");
        compare(request.schemaVersion, 2);
        compare(request.operation.type, "launcherSearch");
        compare(request.operation.data.query, "term");
        protocol.acceptResponse(JSON.stringify({
            "schemaVersion": 2, "requestId": request.requestId,
            "status": "confirmed", "data": []
        }));
        const launch = protocol.launch("org.example.App.desktop", null,
            ["/tmp/literal;touch-not-run"], [],
            "018f3f4c-8af1-7f6b-bf42-1bd472868e66");
        compare(launch.operation.data.request.schemaVersion, 2);
        compare(launch.operation.data.request.desktopId, "org.example.App.desktop");
        compare(launch.operation.data.request.resources[0], "/tmp/literal;touch-not-run");
        compare(launch.operation.data.request.files, undefined);
        compare(launch.operation.data.request.urls, undefined);
        verify(protocol.arbitraryCommand === undefined);
        compare(protocol.request("exec", {"text": "sh -c id"},
            "018f3f4c-8af1-7f6b-bf42-1bd472868e67"), null);
        compare(protocol.acceptResponse(JSON.stringify({
            "schemaVersion": 2,
            "requestId": launch.requestId,
            "status": "confirmed",
            "data": []
        })), true);
        compare(protocol.acceptResponse(JSON.stringify({
            "schemaVersion": 2,
            "requestId": "018f3f4c-8af1-7f6b-bf42-1bd472868e66",
            "status": "confirmed", "data": []
        })), false);
    }

    function test_daily_protocol_rejects_invalid_ids_and_status_field_pairs() {
        const protocol = createTemporaryObject(dailyFactory, testCase);
        compare(protocol.launcherSearch("term", "not-a-uuid"), null);
        const request = protocol.launcherSearch("term",
            "018f3f4c-8af1-7f6b-bf42-1bd472868e65");
        compare(protocol.acceptResponse(JSON.stringify({
            "schemaVersion": 2, "requestId": request.requestId,
            "status": "confirmed", "data": [], "error": "contradiction"
        })), false);
    }

    function test_osd_replay_is_per_output_and_rejects_regression() {
        const model = createTemporaryObject(osdFactory, testCase);
        compare(model.acceptLine(JSON.stringify({
            "sequence": 4,
            "visible": [
                {"schemaVersion": 2, "outputId": "DP-1", "kind": "volume", "level": 0.4,
                 "muted": false, "label": "40%"},
                {"schemaVersion": 2, "outputId": "HDMI-A-1", "kind": "brightness", "level": 0.7,
                 "label": "70%"}
            ],
            "overflowByOutput": {"DP-1": 2}
        })), true);
        compare(model.visibleFor("DP-1").kind, "volume");
        compare(model.visibleFor("HDMI-A-1").kind, "brightness");
        compare(model.overflowFor("DP-1"), 2);
        compare(model.acceptLine('{"sequence":3,"visible":[],"overflowByOutput":{}}'), false);
        compare(model.acceptLine(JSON.stringify({"sequence": 5, "visible": [
            {"schemaVersion": 2, "outputId": "DP-1", "kind": "volume",
             "level": 2, "label": "bad"}], "overflowByOutput": {}})), false);
        model.disconnected("daemon restarted");
        compare(model.visibleFor("DP-1"), null);
        compare(model.sequence, 0);
        model.beginConnection();
        compare(model.acceptLine(JSON.stringify({"sequence": 1,
            "visible": [], "overflowByOutput": {}})), true);
    }

    function test_theme_candidate_is_memory_only_until_typed_ack() {
        const protocol = createTemporaryObject(themeFactory, testCase);
        protocol.mutationsEnabled = true;
        const apply = protocol.apply("theme.one", 4,
            "018f3f4c-8af1-7f6b-bf42-1bd472868e65");
        verify(apply !== null);
        const candidate = {"type": "candidate", "data": {
            "schemaVersion": 2,
            "requestId": "018f3f4c-8af1-7f6b-bf42-1bd472868e65",
            "theme": {"schemaVersion": 1, "id": "theme.one", "name": "One",
                      "origin": "user", "appearance": "dark",
                      "effects": "reduced", "reducedMotion": true,
                      "opaqueFallback": false,
                      "colors": {"background": "#17131f", "surface": "#211c2b",
                                 "textPrimary": "#f7f3ff", "textSecondary": "#d0c7dc",
                                 "accent": "#b9a7ff",
                                 "control": "#76c7aa"}}
        }};
        compare(protocol.acceptLine(JSON.stringify(candidate)), true);
        compare(protocol.previewTheme.id, "theme.one");
        compare(protocol.confirmedTheme, null);
        const ack = protocol.acknowledgement(true);
        compare(ack.schemaVersion, 2);
        compare(ack.requestId, candidate.data.requestId);
        compare(ack.accepted, true);

        protocol.confirmedTheme = candidate.data.theme;
        rollbackSpy.target = protocol;
        rollbackSpy.clear();
        compare(protocol.acceptLine(JSON.stringify({"type": "result", "data": {
            "schemaVersion": 2, "requestId": candidate.data.requestId,
            "status": "error", "error": "desktop acknowledgement rejected"
        }})), true);
        compare(protocol.status, "error");
        compare(protocol.previewTheme, null);
        compare(rollbackSpy.count, 1);
        compare(rollbackSpy.signalArguments[0][0].id, "theme.one");
    }

    function test_notifications_remain_plain_grouped_and_action_expiry_is_visible() {
        const model = createTemporaryObject(notificationFactory, testCase);
        verify(model.acceptDocument({
            "id": 7, "application": "Mail", "summary": "Literal <b>subject</b>",
            "body": "<script>inert</script>", "urgency": "normal", "unread": true,
            "actions": [{"id": "reply", "label": "Reply", "state": "expired"}]
        }));
        compare(model.items[0].summary, "Literal <b>subject</b>");
        compare(model.items[0].body, "<script>inert</script>");
        compare(model.items[0].actions[0].state, "expired");
        compare(model.groups()[0].application, "Mail");
        compare(model.unreadCount, 1);
        model.dnd = true;
        compare(model.items.length, 1);
        model.markAllRead();
        compare(model.unreadCount, 0);
    }

    function test_surface_registry_has_all_daily_surfaces_and_two_output_instances() {
        const registry = createTemporaryObject(registryFactory, testCase);
        registry.registerDailyDesktop();
        const ids = registry.descriptorList.map(function(item) { return item.id; });
        ["notifications", "launcher", "overview", "widgets", "personalization"]
            .forEach(function(id) { verify(ids.indexOf(id) !== -1); });
        compare(registry.registerInstance("launcher", "DP-1", {"name": "one"}), true);
        compare(registry.registerInstance("launcher", "HDMI-A-1", {"name": "two"}), true);
        compare(registry.instanceFor("launcher", "DP-1").name, "one");
        compare(registry.instanceFor("launcher", "HDMI-A-1").name, "two");
    }

    function test_effects_policy_unifies_portal_motion_and_opaque_fallback() {
        const effects = createTemporaryObject(effectsFactory, testCase);
        effects.effectsProfile = "full";
        effects.portalReducedMotion = true;
        compare(effects.motionDuration, 0);
        effects.portalReducedMotion = false;
        effects.opaqueFallback = true;
        compare(effects.surfaceOpacity, 1);
        compare(effects.glowEnabled, false);
        effects.effectsProfile = "none";
        compare(effects.shadowEnabled, false);
    }

    function test_system_palette_tracks_portal_scheme() {
        const palette = createTemporaryObject(paletteFactory, testCase);
        palette.appearanceMode = "system";
        palette.portalDark = false;
        compare(palette.light, true);
        palette.portalDark = true;
        compare(palette.light, false);
    }

    function test_daily_state_routes_only_typed_indexed_and_niri_actions() {
        const fixture = createTemporaryObject(stateFixtureFactory, testCase);
        verify(fixture.state.activateItem("launcher", {
            "desktopId": "org.example.App.desktop", "actionId": "new-window"
        }));
        compare(fixture.lastOperation, "launch");
        compare(fixture.lastData.desktopId, "org.example.App.desktop");
        verify(fixture.state.activateItem("overview", {
            "kind": "workspace", "id": 1
        }));
        compare(fixture.lastOperation, "focusWorkspace");
        verify(fixture.state.closeOverviewItem({"kind": "window", "id": 7}));
        compare(fixture.lastOperation, "closeWindow");
        compare(fixture.state.activateItem("launcher", {"name": "literal shell text"}), false);
        compare(fixture.state.activateItem("overview", {"kind": "command", "id": "sh -c"}), false);
    }

    function test_daily_state_reports_event_offline_and_capability_degradation() {
        const fixture = createTemporaryObject(stateFixtureFactory, testCase);
        fixture.events.connectionState = "offline";
        compare(fixture.state.stateFor("overview"), "offline");
        fixture.events.connectionState = "ready";
        fixture.capabilityStatus = "unsupported";
        compare(fixture.state.stateFor("overview"), "unsupported");
        fixture.capabilityStatus = "permissionDenied";
        compare(fixture.state.stateFor("overview"), "permissionDenied");
    }

    function test_event_backed_system_controls_fail_closed_while_stream_is_offline() {
        const adapter = createTemporaryObject(systemAdapterCoreFactory, testCase);
        adapter.snapshot = {"capabilities": {"network.enabled": "available"}};
        compare(adapter.capabilityState("network.enabled"), "available");
        adapter.runtimeStreamRequired = true;
        adapter.runtimeStreamReady = false;
        compare(adapter.capabilityState("network.enabled"), "unavailable");
        compare(adapter.beginMutation("network.enabled", true), null);
        adapter.runtimeStreamReady = true;
        compare(adapter.capabilityState("network.enabled"), "available");
    }
}
