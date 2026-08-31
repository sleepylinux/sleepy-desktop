import QtQuick 6.0
import QtTest 1.0
import "../../src/services/DesktopCommands.js" as DesktopCommands

TestCase {
    name: "DesktopCommands"

    function test_audio_builders_match_sdk_v3_variants() {
        compare(JSON.stringify(DesktopCommands.audioSetNodeVolume("speaker", 0.5)),
                '{"domain":"audio","action":{"type":"setNodeVolume","data":{"nodeId":"speaker","level":0.5}}}');
        compare(JSON.stringify(DesktopCommands.audioSetDefaultNode("speaker")),
                '{"domain":"audio","action":{"type":"setDefaultNode","data":{"nodeId":"speaker"}}}');
        compare(JSON.stringify(DesktopCommands.audioSetStreamVolume("player", 0.25)),
                '{"domain":"audio","action":{"type":"setStreamVolume","data":{"streamId":"player","level":0.25}}}');
    }

    function test_media_builder_fails_closed_for_unsupported_transports() {
        compare(JSON.stringify(DesktopCommands.mediaTransport("player", "playPause")),
                '{"domain":"media","action":{"type":"transport","data":{"playerId":"player","transport":"playPause"}}}');
        compare(DesktopCommands.mediaTransport("player", "stop"), null);
    }

    function test_compositor_and_appearance_fail_closed_for_unsupported_variants() {
        compare(DesktopCommands.compositor("reloadDynamicConfig"), null);
        compare(DesktopCommands.appearancePreviewWallpaper("moon"), null);
        compare(JSON.stringify(DesktopCommands.appearanceSetWallpaper("moon")),
                '{"type":"setWallpaper","data":{"wallpaperId":"moon"}}');
    }

    function test_session_command_has_no_unlock_variant() {
        compare(DesktopCommands.session("lock"), "lock");
        compare(DesktopCommands.session("unlock"), null);
    }
}
