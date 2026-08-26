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
    Component { id: controlFactory; Services.ControlProtocol {} }
    Component { id: observedRequestCacheFactory; Services.ObservedRequestCache {} }
    Component { id: reconnectBackoffFactory; Services.ReconnectBackoff {} }
    Component { id: lifecycleFactory; Services.ClientRequestLifecycle { timeoutInterval: 40 } }
    Component { id: osdFactory; Services.OsdStreamModel {} }
    Component { id: themeFactory; Services.ThemeProtocol {} }
    Component { id: notificationFactory; Services.NotificationCenterModel {} }
    Component { id: systemAdapterCoreFactory; Services.SystemAdapterCore {} }
    Component { id: registryFactory; Services.SurfaceRegistry {} }
    Component { id: effectsFactory; Theme.EffectsPolicy {} }
    Component { id: paletteFactory; Theme.Palette {} }
    SignalSpy { id: rollbackSpy; signalName: "rollbackRequested" }
    SignalSpy { id: timeoutSpy; signalName: "timedOut" }
    SignalSpy { id: retrySpy; signalName: "retryRequested" }
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
    Component {
        id: sdkWidgetStateFactory
        QtObject {
            id: sdkFixture
            readonly property QtObject events: QtObject {
                property string connectionState: "ready"
                property double generation: 4
                function capability(id) {
                    const values = {
                        "resources":{"cpuUsage":0.25,"memoryUsage":0.5,"loadOne":1.2},
                        "network":{"wifiEnabled":true,"ethernetConnected":false,"connectivity":"full","activeConnectionId":"Sleepy Wi-Fi"},
                        "battery":{"percentage":87,"charging":true,"secondsRemaining":3600},
                        "media":{"playerId":"player","title":"Dreams","artist":"Sleepy","playing":true},
                        "bluetooth":{"powered":true,"connectedDeviceIds":["headset"]},
                        "audio":{"outputLevel":0.4,"outputMuted":false,"inputLevel":0.2,"inputMuted":true}
                    };
                    return values[id] ? {"id":id,"status":"available","available":true,
                        "value":{"type":id,"data":values[id]}} : {"id":id,"status":"unsupported",
                        "available":false,"value":null};
                }
            }
            readonly property QtObject daily: QtObject {
                property string status: "idle"; property string errorString: ""
                signal responseAccepted(var data)
            }
            readonly property Services.DailyDesktopState state: Services.DailyDesktopState {
                events: sdkFixture.events; daily: sdkFixture.daily
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
            "data": {"desktopId": "org.example.App.desktop"}
        })), true);
        compare(protocol.acceptResponse(JSON.stringify({
            "schemaVersion": 2,
            "requestId": "018f3f4c-8af1-7f6b-bf42-1bd472868e66",
            "status": "confirmed", "data": []
        })), false);
    }

    function test_daily_protocol_rejects_operation_specific_malformed_success() {
        const protocol = createTemporaryObject(dailyFactory, testCase);
        let request = protocol.launcherSearch("term", "018f3f4c-8af1-7f6b-bf42-1bd472868e65");
        compare(protocol.acceptResponse(JSON.stringify({"schemaVersion":2,
            "requestId":request.requestId,"status":"confirmed",
            "data":[{"desktopId":"x.desktop","name":"X","icon":null,"actions":[],"extra":true}]})), false);
        request = protocol.weather({"displayName":"Prague","latitude":50,"longitude":14},
            "018f3f4c-8af1-7f6b-bf42-1bd472868e66");
        compare(protocol.acceptResponse(JSON.stringify({"schemaVersion":2,
            "requestId":request.requestId,"status":"confirmed",
            "data":{"status":"online"}})), false);
        compare(protocol.result, null);
    }

    function test_daily_calendar_and_weather_semantics_match_sdk_matrix() {
        const protocol = createTemporaryObject(dailyFactory, testCase);
        function respond(request, data) { return protocol.acceptResponse(JSON.stringify({
            "schemaVersion":2,"requestId":request.requestId,"status":"confirmed","data":data})); }
        function calendar(start, end, eventStart, eventEnd) { return {"schemaVersion":2,
            "providerId":"local-ics","windowStart":start,"windowEnd":end,
            "events":[{"id":"one","summary":"Meeting","startsAt":eventStart,"endsAt":eventEnd,
                "allDay":false,"sourceId":"work"}],"sourceErrors":[]}; }
        let request = protocol.calendar("2026-08-25T10:00:00Z","2026-08-25T12:00:00Z",
            "018f3f4c-8af1-7f6b-bf42-1bd472868e72");
        compare(respond(request, calendar("2026-08-25T10:00:00Z","2026-08-25T12:00:00Z",
            "2026-08-25T10:30:00Z","2026-08-25T11:00:00Z")), true);
        request = protocol.calendar("2026-02-31T10:00:00Z","2026-08-25T12:00:00Z",
            "018f3f4c-8af1-7f6b-bf42-1bd472868e73");
        compare(respond(request, calendar("2026-02-31T10:00:00Z","2026-08-25T12:00:00Z",
            "2026-08-25T10:30:00Z","2026-08-25T11:00:00Z")), false);
        request = protocol.calendar("2026-08-25T12:00:00Z","2026-08-25T10:00:00Z",
            "018f3f4c-8af1-7f6b-bf42-1bd472868e74");
        compare(respond(request, calendar("2026-08-25T12:00:00Z","2026-08-25T10:00:00Z",
            "2026-08-25T10:30:00Z","2026-08-25T11:00:00Z")), false);
        request = protocol.calendar("2026-08-25T10:00:00Z","2026-08-25T12:00:00Z",
            "018f3f4c-8af1-7f6b-bf42-1bd472868e75");
        compare(respond(request, calendar("2026-08-25T10:00:00Z","2026-08-25T12:00:00Z",
            "2026-08-25T11:30:00Z","2026-08-25T11:00:00Z")), false);
        request = protocol.calendar("2026-08-25T10:00:00Z","2026-08-25T12:00:00Z",
            "018f3f4c-8af1-7f6b-bf42-1bd472868e7a");
        const paddedCalendar = calendar("2026-08-25T10:00:00Z","2026-08-25T12:00:00Z",
            "2026-08-25T11:00:00Z","2026-08-25T11:30:00Z");
        paddedCalendar.events[0].summary = " padded ";
        compare(respond(request, paddedCalendar), false);
        function weather(status, diagnostic, at) {
            const value = {"schemaVersion":2,"providerId":"met-no",
                "location":{"displayName":"Prague","latitude":50,"longitude":14},
                "status":status,"cache":status === "online" ? "fresh" : "stale",
                "attribution":"MET Norway","forecast":[{"at":at || "2026-08-25T11:00:00Z",
                    "temperatureC":20,"symbol":"clearsky_day"}]};
            if (diagnostic !== undefined) value.diagnostic = diagnostic;
            return value;
        }
        request = protocol.weather({"displayName":"Prague","latitude":50,"longitude":14},
            "018f3f4c-8af1-7f6b-bf42-1bd472868e76");
        compare(respond(request, weather("online", {"message":"contradiction"})), false);
        request = protocol.weather({"displayName":"Prague","latitude":50,"longitude":14},
            "018f3f4c-8af1-7f6b-bf42-1bd472868e77");
        compare(respond(request, weather("offline")), false);
        request = protocol.weather({"displayName":"Prague","latitude":50,"longitude":14},
            "018f3f4c-8af1-7f6b-bf42-1bd472868e78");
        compare(respond(request, weather("offline", {"message":"network unavailable"})), true);
        request = protocol.weather({"displayName":"Prague","latitude":50,"longitude":14},
            "018f3f4c-8af1-7f6b-bf42-1bd472868e79");
        compare(respond(request, weather("online", undefined, "not-a-time")), false);
        request = protocol.weather({"displayName":"Prague","latitude":50,"longitude":14},
            "018f3f4c-8af1-7f6b-bf42-1bd472868e7b");
        const paddedWeather = weather("online"); paddedWeather.attribution = " MET Norway ";
        compare(respond(request, paddedWeather), false);
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

    function test_control_protocol_accepts_only_event_equal_daemon_confirmation() {
        const protocol = createTemporaryObject(controlFactory, testCase);
        const request = protocol.mutation("network.enabled", true, 9,
            "018f3f4c-8af1-7f6b-bf42-1bd472868e65");
        const result = {"schemaVersion":2,"requestId":request.requestId,"generation":10,
            "status":"confirmed","confirmedEvent":{"schemaVersion":2,"generation":10,
                "eventId":"018f3f4c-8af1-7f6b-bf42-1bd472868e66","emittedAt":"2026-08-25T10:00:00Z",
                "cause":{"kind":"request","requestId":request.requestId},
                "payload":{"type":"fullSnapshot","data":{"capabilities":[]}}}};
        verify(protocol.acceptResponse(JSON.stringify(result)));
        compare(protocol.status, "awaitingEvent");
        result.confirmedEvent.generation = 11;
        protocol.pendingRequestId = request.requestId;
        compare(protocol.acceptResponse(JSON.stringify(result)), false);
    }

    function test_control_client_forgets_completed_and_old_observed_requests() {
        const client = createTemporaryObject(observedRequestCacheFactory, testCase);
        for (let index = 0; index < 65; ++index)
            client.remember("request-" + index, index + 1);
        compare(Object.keys(client.observed).length, 64);
        compare(client.observed["request-0"], undefined);

        compare(client.take("request-64"), 65);
        compare(client.observed["request-64"], undefined);
        compare(client.order.indexOf("request-64"), -1);
        client.clear();
        compare(Object.keys(client.observed).length, 0);
    }

    function test_reconnect_backoff_starts_at_250ms_caps_at_10s_and_resets() {
        const policy = createTemporaryObject(reconnectBackoffFactory, testCase);
        compare(policy.delayMs, 250);
        policy.fail();
        compare(policy.delayMs, 250);
        policy.fail();
        compare(policy.delayMs, 500);
        for (let index = 0; index < 18; ++index) policy.fail();
        compare(policy.delayMs, 10000);
        policy.succeed();
        compare(policy.attempt, 0);
        compare(policy.delayMs, 250);
    }

    function test_client_terminal_success_stops_timeout_and_burst_refresh_coalesces_once() {
        const lifecycle = createTemporaryObject(lifecycleFactory, testCase);
        timeoutSpy.target = lifecycle; retrySpy.target = lifecycle;
        timeoutSpy.clear(); retrySpy.clear();
        verify(lifecycle.begin());
        lifecycle.markDirty(); lifecycle.markDirty();
        lifecycle.finish();
        tryCompare(retrySpy, "count", 1);
        wait(80);
        compare(timeoutSpy.count, 0);
        compare(lifecycle.pending, false);
        compare(lifecycle.dirty, false);
    }

    function test_notification_snapshot_failure_preserves_every_previous_field() {
        const model = createTemporaryObject(notificationFactory, testCase);
        const document = {"schemaVersion":2,"id":7,"applicationId":"Mail","summary":"One",
            "body":"Body","urgency":"normal","createdAt":"2026-08-25T10:00:00Z",
            "read":false,"archived":false,"actions":[]};
        const valid = {"active":[document],"archive":[],"unreadCount":1,
            "groups":[{"applicationId":"Mail","notificationIds":[7]}],"dnd":true,"popupIds":[7]};
        verify(model.acceptSnapshot(valid));
        const before = JSON.stringify({"items":model.items,"archive":model.archive,
            "groups":model.serverGroups,"popups":model.popupIds,"dnd":model.dnd});
        const malformed = JSON.parse(JSON.stringify(valid)); malformed.unreadCount = 0;
        compare(model.acceptSnapshot(malformed), false);
        compare(JSON.stringify({"items":model.items,"archive":model.archive,
            "groups":model.serverGroups,"popups":model.popupIds,"dnd":model.dnd}), before);
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

    function test_theme_result_schema_is_operation_specific_and_lists_catalog() {
        const protocol = createTemporaryObject(themeFactory, testCase);
        const theme = {"schemaVersion":1,"id":"builtin.dark","name":"Dark","origin":"builtin",
            "appearance":"dark","effects":"full","reducedMotion":false,"opaqueFallback":false,
            "colors":{"background":"#17131f","surface":"#211c2b","textPrimary":"#f7f3ff",
                "textSecondary":"#d0c7dc","accent":"#b9a7ff","control":"#76c7aa"}};
        let request = protocol.list("018f3f4c-8af1-7f6b-bf42-1bd472868e70");
        compare(protocol.acceptLine(JSON.stringify({"type":"result","data":{"schemaVersion":2,
            "requestId":request.requestId,"status":"confirmed","themes":[theme]}})), true);
        compare(protocol.themes.length, 1);
        request = protocol.get("018f3f4c-8af1-7f6b-bf42-1bd472868e71");
        compare(protocol.acceptLine(JSON.stringify({"type":"result","data":{"schemaVersion":2,
            "requestId":request.requestId,"status":"confirmed","theme":theme,"generation":3}})), false);
        compare(protocol.confirmedTheme, null);
    }

    function test_notifications_remain_plain_grouped_and_action_expiry_is_visible() {
        const model = createTemporaryObject(notificationFactory, testCase);
        verify(model.acceptDocument({
            "schemaVersion": 2, "id": 7, "applicationId": "Mail", "summary": "Literal <b>subject</b>",
            "body": "<script>inert</script>", "urgency": "normal", "read": false,
            "createdAt": "2026-08-25T10:00:00Z", "archived": false,
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
        compare(registry.availableDescriptors().length, 0);
        verify(registry.setAvailability("launcher", true));
        compare(registry.availableDescriptors().length, 1);
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

    function test_widget_cards_use_exact_sdk_fields_and_human_primary_values() {
        const fixture = createTemporaryObject(sdkWidgetStateFactory, testCase);
        const cards = fixture.state.systemCards();
        compare(cards.find(function(item) { return item.id === "resources"; }).summary,
            "CPU 25% · RAM 50% · load 1.2");
        compare(cards.find(function(item) { return item.id === "battery"; }).summary,
            "87% · charging");
        compare(cards.find(function(item) { return item.id === "bluetooth"; }).summary,
            "Powered · 1 connected");
        compare(cards.find(function(item) { return item.id === "audio"; }).summary,
            "Output 40% · input 20% · muted");
    }

    function test_system_palette_tracks_portal_scheme() {
        const palette = createTemporaryObject(paletteFactory, testCase);
        palette.appearanceMode = "system";
        palette.customColors = {"background":"#111111","surface":"#222222",
            "textPrimary":"#eeeeee","textSecondary":"#cccccc","accent":"#b9a7ff","control":"#76c7aa"};
        palette.portalDark = false;
        compare(palette.light, true);
        compare(palette.shellBackground.toString(), "#f1eef8");
        compare(palette.surface.toString(), "#fbf9ff");
        compare(palette.textPrimary.toString(), "#251f2e");
        verify(contrastRatio(palette.accent, palette.shellBackground) >= 4.5,
            "system-light accent text contrast must be at least 4.5:1");
        verify(contrastRatio(palette.accent, palette.surface) >= 4.5,
            "system-light accent surface contrast must be at least 4.5:1");
        palette.portalDark = true;
        compare(palette.light, false);
        compare(palette.shellBackground.toString(), "#17131f");
        compare(palette.surface.toString(), "#211c2b");
        compare(palette.textPrimary.toString(), "#f7f3ff");
        verify(contrastRatio(palette.accent, palette.shellBackground) >= 4.5);
        verify(contrastRatio(palette.accent, palette.surface) >= 4.5);
    }

    function contrastRatio(first, second) {
        function linear(channel) {
            return channel <= 0.04045 ? channel / 12.92
                                      : Math.pow((channel + 0.055) / 1.055, 2.4);
        }
        function luminance(color) {
            return 0.2126 * linear(color.r) + 0.7152 * linear(color.g)
                + 0.0722 * linear(color.b);
        }
        const firstLuminance = luminance(first);
        const secondLuminance = luminance(second);
        return (Math.max(firstLuminance, secondLuminance) + 0.05)
            / (Math.min(firstLuminance, secondLuminance) + 0.05);
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
