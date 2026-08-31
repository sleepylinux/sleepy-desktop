import QtQuick 6.0
import QtTest 1.0
import "../../src/services" as Services

TestCase {
    id: testCase

    name: "DesktopProtocol"

    Component {
        id: protocolFactory

        Services.DesktopProtocol {}
    }

    Component { id: signalSpy; SignalSpy {} }

    readonly property string requestId: "22222222-2222-4222-8222-222222222222"
    readonly property string otherRequestId: "33333333-3333-4333-8333-333333333333"

    function freshProtocol() {
        const protocol = createTemporaryObject(protocolFactory, testCase);
        protocol.minimumRetryMs = 250;
        protocol.maximumRetryMs = 10000;
        return protocol;
    }

    function unavailableCapability() {
        return {"status": "unsupported", "diagnostic": {"message": "not wired"}};
    }

    function availability() {
        return {"status": "available"};
    }

    function validTheme() {
        return {
            "schemaVersion": 1,
            "id": "default",
            "name": "Default",
            "origin": "builtin",
            "appearance": "dark",
            "effects": "full",
            "reducedMotion": false,
            "opaqueFallback": false,
            "colors": {
                "background": "#000000",
                "surface": "#111111",
                "textPrimary": "#ffffff",
                "textSecondary": "#d0d0d0",
                "accent": "#66ccff",
                "control": "#eeeeee"
            }
        };
    }

    function validSnapshot() {
        return {
            "system": {
                "network": unavailableCapability(),
                "bluetooth": unavailableCapability(),
                "audio": unavailableCapability(),
                "media": unavailableCapability(),
                "battery": unavailableCapability(),
                "brightness": unavailableCapability(),
                "nightLight": unavailableCapability(),
                "power": unavailableCapability(),
                "osd": unavailableCapability(),
                "lock": unavailableCapability()
            },
            "compositor": {
                "hyprland": unavailableCapability()
            },
            "notifications": {
                "availability": availability(),
                "dnd": false,
                "active": []
            },
            "launcher": {
                "availability": availability(),
                "entries": []
            },
            "calendar": {
                "availability": availability(),
                "snapshot": {
                    "schemaVersion": 2,
                    "providerId": "local",
                    "windowStart": "2026-08-31T00:00:00Z",
                    "windowEnd": "2026-09-01T00:00:00Z",
                    "events": [],
                    "sourceErrors": []
                }
            },
            "weather": {
                "availability": availability(),
                "snapshot": {
                    "schemaVersion": 2,
                    "providerId": "weather",
                    "location": {
                        "displayName": "Prague",
                        "latitude": 50.0755,
                        "longitude": 14.4378
                    },
                    "status": "online",
                    "cache": "fresh",
                    "attribution": "Test fixture",
                    "forecast": []
                }
            },
            "appearance": {
                "availability": availability(),
                "theme": validTheme(),
                "wallpaperId": "moon"
            },
            "resources": {
                "availability": availability(),
                "samples": []
            },
            "utilities": {
                "trayItems": unavailableCapability(),
                "clipboardEntries": unavailableCapability(),
                "recording": {"status": "available", "data": {"status": "inactive"}},
                "idleInhibited": {"status": "available", "data": false},
                "gameMode": {"status": "available", "data": false},
                "screenshot": availability(),
                "colorPicker": availability()
            }
        };
    }

    function clone(value) {
        return JSON.parse(JSON.stringify(value));
    }

    function requestCause(id) {
        return { "kind": "request", "requestId": id };
    }

    function envelope(generation, payload, cause) {
        return {
            "schemaVersion": 3,
            "generation": generation,
            "eventId": "11111111-1111-4111-8111-111111111111",
            "emittedAt": "2026-08-31T00:00:00Z",
            "cause": cause || { "kind": "external" },
            "payload": payload || { "type": "fullSnapshot", "data": validSnapshot() }
        };
    }

    function semanticSnapshot() {
        const snapshot = validSnapshot();
        snapshot.system.network = {
            "status": "available",
            "data": {
                "wifiEnabled": true,
                "scanning": false,
                "accessPoints": [
                    {"id": "ap-1", "ssid": "Home", "signalLevel": 0.8, "secured": true},
                    {"id": "ap-2", "ssid": "Office", "signalLevel": 0.4, "secured": true}
                ],
                "connections": [
                    {"id": "wifi-home", "name": "Home", "kind": "wifi", "connected": true},
                    {"id": "vpn-work", "name": "Work VPN", "kind": "vpn", "connected": false}
                ]
            }
        };
        snapshot.system.bluetooth = {
            "status": "available",
            "data": {
                "powered": true,
                "scanning": false,
                "devices": [
                    {"id": "keyboard", "name": "Keyboard", "paired": true, "connected": true},
                    {"id": "headset", "name": "Headset", "paired": true, "connected": false}
                ]
            }
        };
        snapshot.system.audio = {
            "status": "available",
            "data": {
                "nodes": [
                    {"id": "speaker", "name": "Speakers", "kind": "output", "volume": 0.7, "muted": false, "isDefault": true},
                    {"id": "mic", "name": "Microphone", "kind": "input", "volume": 0.6, "muted": false, "isDefault": true}
                ],
                "streams": [
                    {"id": "player", "name": "Player", "nodeId": "speaker", "volume": 0.5, "muted": false}
                ]
            }
        };
        snapshot.system.media = {
            "status": "available",
            "data": {
                "players": [
                    {"id": "player", "identity": "player.desktop", "title": "Song", "artist": "Artist", "playing": true, "progress": 0.5}
                ]
            }
        };
        snapshot.system.battery = {"status": "available", "data": {"level": 0.9, "charging": false, "secondsRemaining": 3600}};
        snapshot.system.brightness = {"status": "available", "data": {"level": 0.7}};
        snapshot.system.nightLight = {"status": "available", "data": {"enabled": false}};
        snapshot.system.power = {
            "status": "available",
            "data": {"activeProfile": "balanced", "availableProfiles": ["power-saver", "balanced", "performance"]}
        };
        snapshot.system.osd = {
            "status": "available",
            "data": {
                "current": {"schemaVersion": 2, "outputId": "speaker", "kind": "volume", "level": 0.7, "muted": false, "label": "Volume"},
                "history": [
                    {"schemaVersion": 2, "outputId": "display", "kind": "brightness", "level": 0.7, "label": "Brightness"}
                ]
            }
        };
        snapshot.system.lock = {"status": "available", "data": {"secure": true}};
        snapshot.compositor.hyprland = {
            "status": "available",
            "data": validHyprlandData()
        };
        snapshot.notifications.active = [
            {
                "schemaVersion": 2,
                "id": 7,
                "applicationId": "org.sleepy.Test",
                "summary": "Ready",
                "body": "Body",
                "urgency": "normal",
                "createdAt": "2026-08-31T01:00:00Z",
                "read": false,
                "archived": false,
                "actions": [
                    {"id": "default", "label": "Open", "state": "available"},
                    {"id": "dismiss", "label": "Dismiss", "state": "expired"}
                ]
            }
        ];
        snapshot.launcher.entries = [
            {"id": "org.sleepy.Test.desktop", "name": "Sleepy Test", "icon": "sleepy"},
            {"id": "org.sleepy.Other.desktop", "name": "Sleepy Other", "icon": "other"}
        ];
        snapshot.calendar.snapshot.events = [
            {
                "id": "event-1",
                "summary": "Standup",
                "startsAt": "2026-08-31T09:00:00Z",
                "endsAt": "2026-08-31T09:30:00Z",
                "allDay": false,
                "sourceId": "local"
            }
        ];
        snapshot.weather.snapshot.forecast = [
            {"at": "2026-08-31T12:00:00Z", "temperatureC": 22.5, "symbol": "clear"}
        ];
        snapshot.resources.samples = [
            {"id": "cpu", "cpuUsage": 0.4, "memoryUsage": 0.5, "loadOne": 1.1},
            {"id": "gpu", "cpuUsage": 0.1, "memoryUsage": 0.2, "loadOne": 0}
        ];
        snapshot.utilities.trayItems = {
            "status": "available",
            "data": [
                {"id": "tray-1", "title": "Tray 1", "menu": menuNode("root-1", [])},
                {"id": "tray-2", "title": "Tray 2", "menu": menuNode("root-2", [menuNode("child-2", [])])}
            ]
        };
        snapshot.utilities.clipboardEntries = {
            "status": "available",
            "data": [
                {"id": "clip-1", "preview": "one", "mimeType": "text/plain", "byteLength": 3},
                {"id": "clip-2", "preview": "two", "mimeType": "text/plain", "byteLength": 3}
            ]
        };
        return snapshot;
    }

    function validHyprlandData() {
        return {
            "actionCapabilities": {
                "focusWindow": true,
                "moveWindowToWorkspace": true,
                "closeWindow": true,
                "focusWorkspace": true,
                "moveWorkspaceToMonitor": true,
                "toggleFullscreen": true,
                "toggleFloating": true,
                "togglePinned": true,
                "toggleGroup": true,
                "exit": true
            },
            "monitors": [
                {"id": "monitor-1", "name": "eDP-1", "width": 1920, "height": 1080, "scale": 1, "focused": true},
                {"id": "monitor-2", "name": "HDMI-A-1", "width": 1280, "height": 720, "scale": 1, "focused": false}
            ],
            "workspaces": [
                {"id": "1", "name": "1", "monitorId": "monitor-1", "focused": true},
                {"id": "2", "name": "2", "monitorId": "monitor-2", "focused": false}
            ],
            "windows": [
                {"id": "win-1", "title": "Terminal", "applicationId": "terminal", "workspaceId": "1", "focused": true, "fullscreen": false, "floating": false, "pinned": false, "grouped": false},
                {"id": "win-2", "title": "Editor", "applicationId": "editor", "workspaceId": "2", "focused": false, "fullscreen": false, "floating": false, "pinned": false, "grouped": false}
            ]
        };
    }

    function menuNode(id, children) {
        return {"id": id, "label": id, "enabled": true, "children": children || []};
    }

    function menuWithChildren(prefix, count) {
        const children = [];
        for (let index = 0; index < count; ++index)
            children.push(menuNode(prefix + "-child-" + index, []));
        return menuNode(prefix + "-root", children);
    }

    function expectNoCommandResultMutation(protocol, before, commandSpy, eventSpy) {
        compare(protocol.lastCommandResult, before.lastCommandResult);
        compare(JSON.stringify(protocol.observedRequestIds), before.observedRequestIds);
        compare(JSON.stringify(protocol.observedRequestOrder), before.observedRequestOrder);
        compare(commandSpy.count, 0);
        compare(eventSpy.count, 0);
    }

    function commandResultEnvelope(cause, resultRequest, resultGeneration, envelopeGeneration) {
        return envelope(envelopeGeneration, {
            "type": "commandResult",
            "data": {
                "schemaVersion": 3,
                "requestId": resultRequest,
                "generation": resultGeneration,
                "status": "succeeded"
            }
        }, cause);
    }

    function test_generation_accepts_safe_integer_beyond_qml_int32() {
        const protocol = freshProtocol();

        verify(protocol.acceptEnvelope(envelope(4294967296)));

        compare(protocol.generation, 4294967296);
        compare(protocol.connectionState, "ready");
    }

    function test_generation_rejects_values_outside_javascript_safe_integer_range() {
        const protocol = freshProtocol();

        verify(!protocol.acceptEnvelope(envelope(9007199254740992)));

        compare(protocol.connectionState, "error");
    }

    function test_full_snapshot_rejects_missing_top_level_domain() {
        const protocol = freshProtocol();
        const snapshot = validSnapshot();
        delete snapshot.weather;

        verify(!protocol.acceptEnvelope(envelope(1, {
            "type": "fullSnapshot",
            "data": snapshot
        })));

        compare(protocol.connectionState, "error");
        verify(!protocol.snapshotReceived);
    }

    function test_full_snapshot_rejects_unknown_top_level_domain() {
        const protocol = freshProtocol();
        const snapshot = validSnapshot();
        snapshot.extra = {};

        verify(!protocol.acceptEnvelope(envelope(1, {
            "type": "fullSnapshot",
            "data": snapshot
        })));

        compare(protocol.connectionState, "error");
        verify(!protocol.snapshotReceived);
    }

    function test_full_snapshot_rejects_malformed_capability_record() {
        const protocol = freshProtocol();
        const snapshot = validSnapshot();
        snapshot.system.network = {
            "status": "available",
            "data": {"wifiEnabled": true}
        };

        verify(!protocol.acceptEnvelope(envelope(1, {
            "type": "fullSnapshot",
            "data": snapshot
        })));

        compare(protocol.connectionState, "error");
        verify(!protocol.snapshotReceived);
    }

    function test_domain_update_rejects_unknown_update_field() {
        const protocol = freshProtocol();
        verify(protocol.acceptEnvelope(envelope(1)));

        verify(!protocol.acceptEnvelope(envelope(2, {
            "type": "domainUpdate",
            "data": {
                "topic": "notifications",
                "update": {
                    "availability": availability(),
                    "dnd": true,
                    "active": [],
                    "extra": true
                }
            }
        })));

        compare(protocol.connectionState, "error");
    }

    function test_domain_update_rejects_unknown_domain() {
        const protocol = freshProtocol();
        verify(protocol.acceptEnvelope(envelope(1)));

        verify(!protocol.acceptEnvelope(envelope(2, {
            "type": "domainUpdate",
            "data": {
                "topic": "system",
                "update": {
                    "domain": "unknown",
                    "data": unavailableCapability()
                }
            }
        })));

        compare(protocol.connectionState, "error");
        verify(!Object.prototype.hasOwnProperty.call(protocol.snapshot.system, "unknown"));
    }

    function test_domain_update_rejects_malformed_capability_data() {
        const protocol = freshProtocol();
        const before = validSnapshot().system.network;
        verify(protocol.acceptEnvelope(envelope(1)));
        compare(JSON.stringify(protocol.snapshot.system.network), JSON.stringify(before));

        verify(!protocol.acceptEnvelope(envelope(2, {
            "type": "domainUpdate",
            "data": {
                "topic": "system",
                "update": {
                    "domain": "network",
                    "data": {
                        "status": "available",
                        "data": {"wifiEnabled": true}
                    }
                }
            }
        })));

        compare(protocol.connectionState, "error");
        compare(JSON.stringify(protocol.snapshot.system.network), JSON.stringify(before));
    }

    function test_command_result_event_accepts_correlated_request_cause() {
        const protocol = freshProtocol();
        verify(protocol.acceptEnvelope(envelope(1)));
        const spy = signalSpy.createObject(protocol, {
            "target": protocol,
            "signalName": "commandResultAccepted"
        });

        verify(protocol.acceptEnvelope(commandResultEnvelope(
            requestCause(requestId), requestId, 2, 2)));

        compare(spy.count, 1);
        compare(protocol.lastCommandResult.requestId, requestId);
        compare(protocol.lastCommandResult.generation, 2);
        compare(protocol.observedRequestIds[requestId], 2);
    }

    function test_command_result_event_rejects_uncorrelated_envelope_without_mutating_data_data() {
        return [
            {
                "tag": "external cause cannot carry a command result",
                "event": commandResultEnvelope({"kind": "external"}, requestId, 2, 2)
            },
            {
                "tag": "replay cause cannot carry a command result",
                "event": commandResultEnvelope({"kind": "replay"}, requestId, 2, 2)
            },
            {
                "tag": "request cause id must match result id",
                "event": commandResultEnvelope(requestCause(requestId), otherRequestId, 2, 2)
            },
            {
                "tag": "result generation must match envelope generation",
                "event": commandResultEnvelope(requestCause(requestId), requestId, 1, 2)
            }
        ];
    }

    function test_command_result_event_rejects_uncorrelated_envelope_without_mutating_data(data) {
        const protocol = freshProtocol();
        verify(protocol.acceptEnvelope(envelope(1)));
        const commandSpy = signalSpy.createObject(protocol, {
            "target": protocol,
            "signalName": "commandResultAccepted"
        });
        const eventSpy = signalSpy.createObject(protocol, {
            "target": protocol,
            "signalName": "eventAccepted"
        });
        const before = {
            "lastCommandResult": protocol.lastCommandResult,
            "observedRequestIds": JSON.stringify(protocol.observedRequestIds),
            "observedRequestOrder": JSON.stringify(protocol.observedRequestOrder)
        };

        verify(!protocol.acceptEnvelope(data.event));

        expectNoCommandResultMutation(protocol, before, commandSpy, eventSpy);
    }

    function test_full_snapshot_accepts_sdk_semantic_fixture() {
        const protocol = freshProtocol();

        verify(protocol.acceptEnvelope(envelope(1, {
            "type": "fullSnapshot",
            "data": semanticSnapshot()
        })));

        compare(protocol.connectionState, "ready");
        verify(protocol.snapshotReceived);
    }

    function snapshotSemanticInvalidCases() {
        return [
            {
                "tag": "network access point ids must be unique",
                "mutate": function(snapshot) { snapshot.system.network.data.accessPoints[1].id = "ap-1"; }
            },
            {
                "tag": "network connection ids must be unique",
                "mutate": function(snapshot) { snapshot.system.network.data.connections[1].id = "wifi-home"; }
            },
            {
                "tag": "bluetooth device ids must be unique",
                "mutate": function(snapshot) { snapshot.system.bluetooth.data.devices[1].id = "keyboard"; }
            },
            {
                "tag": "audio node ids must be unique",
                "mutate": function(snapshot) { snapshot.system.audio.data.nodes[1].id = "speaker"; }
            },
            {
                "tag": "audio stream ids must be unique",
                "mutate": function(snapshot) {
                    snapshot.system.audio.data.streams.push(clone(snapshot.system.audio.data.streams[0]));
                }
            },
            {
                "tag": "audio stream nodeId must reference a node",
                "mutate": function(snapshot) { snapshot.system.audio.data.streams[0].nodeId = "missing"; }
            },
            {
                "tag": "media player ids must be unique",
                "mutate": function(snapshot) {
                    snapshot.system.media.data.players.push(clone(snapshot.system.media.data.players[0]));
                }
            },
            {
                "tag": "power activeProfile must be available",
                "mutate": function(snapshot) { snapshot.system.power.data.availableProfiles = ["power-saver", "performance"]; }
            },
            {
                "tag": "monitor ids must be unique",
                "mutate": function(snapshot) { snapshot.compositor.hyprland.data.monitors[1].id = "monitor-1"; }
            },
            {
                "tag": "workspace monitorId must reference a monitor",
                "mutate": function(snapshot) { snapshot.compositor.hyprland.data.workspaces[0].monitorId = "missing"; }
            },
            {
                "tag": "window workspaceId must reference a workspace",
                "mutate": function(snapshot) { snapshot.compositor.hyprland.data.windows[0].workspaceId = "missing"; }
            },
            {
                "tag": "Hyprland may contain at most one focused monitor",
                "mutate": function(snapshot) { snapshot.compositor.hyprland.data.monitors[1].focused = true; }
            },
            {
                "tag": "active notification ids must be unique",
                "mutate": function(snapshot) { snapshot.notifications.active.push(clone(snapshot.notifications.active[0])); }
            },
            {
                "tag": "notification action ids must be unique",
                "mutate": function(snapshot) { snapshot.notifications.active[0].actions[1].id = "default"; }
            },
            {
                "tag": "launcher entry ids must be unique",
                "mutate": function(snapshot) { snapshot.launcher.entries[1].id = "org.sleepy.Test.desktop"; }
            },
            {
                "tag": "calendar window must be ordered",
                "mutate": function(snapshot) { snapshot.calendar.snapshot.windowEnd = snapshot.calendar.snapshot.windowStart; }
            },
            {
                "tag": "calendar event ids must be unique",
                "mutate": function(snapshot) { snapshot.calendar.snapshot.events.push(clone(snapshot.calendar.snapshot.events[0])); }
            },
            {
                "tag": "calendar event interval must be ordered",
                "mutate": function(snapshot) { snapshot.calendar.snapshot.events[0].endsAt = snapshot.calendar.snapshot.events[0].startsAt; }
            },
            {
                "tag": "user theme ids must be canonical UUIDs",
                "mutate": function(snapshot) {
                    snapshot.appearance.theme.origin = "user";
                    snapshot.appearance.theme.id = "not-a-uuid";
                }
            },
            {
                "tag": "theme semantic colors must meet SDK contrast",
                "mutate": function(snapshot) { snapshot.appearance.theme.colors.textPrimary = "#111111"; }
            },
            {
                "tag": "resource sample ids must be unique",
                "mutate": function(snapshot) { snapshot.resources.samples[1].id = "cpu"; }
            },
            {
                "tag": "tray item ids must be unique",
                "mutate": function(snapshot) { snapshot.utilities.trayItems.data[1].id = "tray-1"; }
            },
            {
                "tag": "tray menu node ids must be unique per item",
                "mutate": function(snapshot) {
                    snapshot.utilities.trayItems.data[1].menu.children.push(menuNode("root-2", []));
                }
            },
            {
                "tag": "clipboard entry ids must be unique",
                "mutate": function(snapshot) { snapshot.utilities.clipboardEntries.data[1].id = "clip-1"; }
            }
        ];
    }

    function test_full_snapshot_rejects_sdk_semantic_invariants_without_mutation_data() {
        return snapshotSemanticInvalidCases();
    }

    function test_full_snapshot_rejects_sdk_semantic_invariants_without_mutation(data) {
        const protocol = freshProtocol();
        const snapshot = semanticSnapshot();
        data.mutate(snapshot);

        verify(!protocol.acceptEnvelope(envelope(1, {
            "type": "fullSnapshot",
            "data": snapshot
        })));

        compare(protocol.connectionState, "error");
        verify(!protocol.snapshotReceived);
        compare(JSON.stringify(protocol.snapshot), "{}");
    }

    function domainUpdateInvalidCases() {
        return [
            {
                "tag": "system network update rejects duplicate access point ids",
                "update": function() {
                    const data = clone(semanticSnapshot().system.network);
                    data.data.accessPoints[1].id = "ap-1";
                    return {"topic": "system", "update": {"domain": "network", "data": data}};
                }
            },
            {
                "tag": "system audio update rejects stream nodeId without node",
                "update": function() {
                    const data = clone(semanticSnapshot().system.audio);
                    data.data.streams[0].nodeId = "missing";
                    return {"topic": "system", "update": {"domain": "audio", "data": data}};
                }
            },
            {
                "tag": "system power update rejects active profile outside available profiles",
                "update": function() {
                    const data = clone(semanticSnapshot().system.power);
                    data.data.availableProfiles = ["performance"];
                    return {"topic": "system", "update": {"domain": "power", "data": data}};
                }
            },
            {
                "tag": "compositor hyprland update rejects workspace foreign key misses",
                "update": function() {
                    const data = validHyprlandData();
                    data.workspaces[0].monitorId = "missing";
                    return {"topic": "compositor", "update": {"domain": "hyprland", "data": {"status": "available", "data": data}}};
                }
            },
            {
                "tag": "compositor monitors update rejects duplicate ids",
                "update": function() {
                    const data = validHyprlandData().monitors;
                    data[1].id = "monitor-1";
                    return {"topic": "compositor", "update": {"domain": "monitors", "data": data}};
                }
            },
            {
                "tag": "compositor workspaces update rejects ambiguous focus",
                "update": function() {
                    const data = validHyprlandData().workspaces;
                    data[1].focused = true;
                    return {"topic": "compositor", "update": {"domain": "workspaces", "data": data}};
                }
            },
            {
                "tag": "compositor windows update rejects duplicate ids",
                "update": function() {
                    const data = validHyprlandData().windows;
                    data[1].id = "win-1";
                    return {"topic": "compositor", "update": {"domain": "windows", "data": data}};
                }
            },
            {
                "tag": "notifications update rejects duplicate notification ids",
                "update": function() {
                    const data = clone(semanticSnapshot().notifications);
                    data.active.push(clone(data.active[0]));
                    return {"topic": "notifications", "update": data};
                }
            },
            {
                "tag": "launcher update rejects duplicate entry ids",
                "update": function() {
                    const data = clone(semanticSnapshot().launcher);
                    data.entries[1].id = "org.sleepy.Test.desktop";
                    return {"topic": "launcher", "update": data};
                }
            },
            {
                "tag": "calendar update rejects reversed event intervals",
                "update": function() {
                    const data = clone(semanticSnapshot().calendar);
                    data.snapshot.events[0].endsAt = data.snapshot.events[0].startsAt;
                    return {"topic": "calendar", "update": data};
                }
            },
            {
                "tag": "weather update rejects non-finite forecast temperatures",
                "update": function() {
                    const data = clone(semanticSnapshot().weather);
                    data.snapshot.forecast[0].temperatureC = Number.POSITIVE_INFINITY;
                    return {"topic": "weather", "update": data};
                }
            },
            {
                "tag": "appearance update rejects low contrast themes",
                "update": function() {
                    const data = clone(semanticSnapshot().appearance);
                    data.theme.colors.accent = "#000000";
                    return {"topic": "appearance", "update": data};
                }
            },
            {
                "tag": "resources update rejects duplicate sample ids",
                "update": function() {
                    const data = clone(semanticSnapshot().resources);
                    data.samples[1].id = "cpu";
                    return {"topic": "resources", "update": data};
                }
            },
            {
                "tag": "utilities trayItems update rejects aggregate menu node cap",
                "update": function() {
                    return {
                        "topic": "utilities",
                        "update": {
                            "domain": "trayItems",
                            "data": {
                                "status": "available",
                                "data": [
                                    {"id": "tray-huge", "title": "Huge", "menu": menuWithChildren("huge", 65535)},
                                    {"id": "tray-extra", "title": "Extra", "menu": menuNode("extra-root", [])}
                                ]
                            }
                        }
                    };
                }
            },
            {
                "tag": "utilities clipboard update rejects duplicate entry ids",
                "update": function() {
                    const data = clone(semanticSnapshot().utilities.clipboardEntries);
                    data.data[1].id = "clip-1";
                    return {"topic": "utilities", "update": {"domain": "clipboardEntries", "data": data}};
                }
            }
        ];
    }

    function test_domain_update_rejects_sdk_semantic_invariants_without_mutation_data() {
        return domainUpdateInvalidCases();
    }

    function test_domain_update_rejects_sdk_semantic_invariants_without_mutation(data) {
        const protocol = freshProtocol();
        verify(protocol.acceptEnvelope(envelope(1, {
            "type": "fullSnapshot",
            "data": semanticSnapshot()
        })));
        const before = JSON.stringify(protocol.snapshot);

        verify(!protocol.acceptEnvelope(envelope(2, {
            "type": "domainUpdate",
            "data": data.update()
        })));

        compare(protocol.connectionState, "error");
        compare(JSON.stringify(protocol.snapshot), before);
    }

    function test_retry_delay_is_bounded_between_protocol_limits() {
        const protocol = freshProtocol();

        compare(protocol.boundedRetryDelay(0), 250);
        compare(protocol.boundedRetryDelay(99), 10000);
    }
}
