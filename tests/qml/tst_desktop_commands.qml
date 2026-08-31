import QtQuick 6.0
import QtTest 1.0
import "../../src/services/DesktopCommands.js" as DesktopCommands

TestCase {
    name: "DesktopCommands"

    function readCorpus() {
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl("../fixtures/desktop-command-corpus.json"), false);
        request.send();
        verify(request.status === 0 || request.status === 200);
        return JSON.parse(request.responseText);
    }

    function invokeBuilder(entry) {
        const builder = DesktopCommands[entry.builder];
        verify(typeof builder === "function");
        return builder.apply(null, entry.args);
    }

    function test_builders_match_single_schema_corpus_data() {
        return readCorpus().map(function(entry) {
            return {"tag": entry.name, "entry": entry};
        });
    }

    function test_builders_match_single_schema_corpus(data) {
        const actual = invokeBuilder(data.entry);
        compare(JSON.stringify(actual), JSON.stringify(data.entry.command));
    }

    function longString(length) {
        return "x".repeat(length);
    }

    function test_builders_reject_schema_invalid_arbitrary_inputs_data() {
        const longId = longString(257);
        const longResource = longString(4097);
        return [
            {
                "tag": "stable ids longer than SDK maximum",
                "actual": DesktopCommands.networkConnectWifi(longId)
            },
            {
                "tag": "stable ids with control characters",
                "actual": DesktopCommands.audioSetDefaultNode("speaker" + String.fromCharCode(1))
            },
            {
                "tag": "normalized ranges are not clamped into validity",
                "actual": DesktopCommands.audioSetNodeVolume("speaker", 1.5)
            },
            {
                "tag": "NaN normalized values are rejected",
                "actual": DesktopCommands.displaySetBrightness("eDP-1", Number.NaN)
            },
            {
                "tag": "launcher resources must be arrays",
                "actual": DesktopCommands.launcherLaunch("org.sleepy.Test.desktop", "not-array", "")
            },
            {
                "tag": "launcher resources must be strings",
                "actual": DesktopCommands.launcherLaunch("org.sleepy.Test.desktop", [7], "")
            },
            {
                "tag": "launcher resources must be non-empty",
                "actual": DesktopCommands.launcherLaunch("org.sleepy.Test.desktop", [""], "")
            },
            {
                "tag": "launcher resources must be NUL-free",
                "actual": DesktopCommands.launcherLaunch("org.sleepy.Test.desktop", ["a" + String.fromCharCode(0) + "b"], "")
            },
            {
                "tag": "launcher resources must respect SDK maximum length",
                "actual": DesktopCommands.launcherLaunch("org.sleepy.Test.desktop", [longResource], "")
            },
            {
                "tag": "launcher actionId is an optional bounded stable id",
                "actual": DesktopCommands.launcherLaunch("org.sleepy.Test.desktop", [], longId)
            },
            {
                "tag": "session enum inputs are exact",
                "actual": DesktopCommands.session("unlock")
            }
        ];
    }

    function test_builders_reject_schema_invalid_arbitrary_inputs(data) {
        compare(data.actual, null);
    }
}
