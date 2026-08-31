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
                "background": "#101010",
                "surface": "#202020",
                "textPrimary": "#ffffff",
                "textSecondary": "#bbbbbb",
                "accent": "#99ccff",
                "control": "#303030"
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

    function envelope(generation, payload) {
        return {
            "schemaVersion": 3,
            "generation": generation,
            "eventId": "11111111-1111-4111-8111-111111111111",
            "emittedAt": "2026-08-31T00:00:00Z",
            "cause": { "kind": "external" },
            "payload": payload || { "type": "fullSnapshot", "data": validSnapshot() }
        };
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

    function test_retry_delay_is_bounded_between_protocol_limits() {
        const protocol = freshProtocol();

        compare(protocol.boundedRetryDelay(0), 250);
        compare(protocol.boundedRetryDelay(99), 10000);
    }
}
